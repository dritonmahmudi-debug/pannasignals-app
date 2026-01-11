# === CONFIGURATION ===
TF_4H = "4h"
TF_1H = "1h"
TF_ENTRY = "15m"  # Change to "5m" for more sensitive entries
EMA_FAST = 21
EMA_SLOW = 50
EMA_TREND = 200
PIVOT_LEFT = 2
PIVOT_RIGHT = 2
MIN_MINUTES_BETWEEN_SIGNALS = 60
RR = 2.0
LOOKBACK_BARS = 120

# === Helper: fetch_ohlc with lowercase columns ===
def fetch_ohlc(symbol, interval, lookback_days=LOOKBACK_BARS):
    # This should return a DataFrame with columns: open, high, low, close, volume, time (all lowercase)
    # Implement your real fetch here. For now, fallback to existing logic if present.
    df = ... # fetch logic here
    df.columns = [c.lower() for c in df.columns]
    return df

# ===================== SIGNAL LOGIC + AUTO CLOSE =====================
import threading

open_signals = {}
open_signals_lock = threading.Lock()

# === Helper: EMA ===
def ema(series, length):
    return series.ewm(span=length, adjust=False).mean()

# === Helper: Find pivots ===
def find_swings_pivots(df, left=PIVOT_LEFT, right=PIVOT_RIGHT):
    highs = df['high']
    lows = df['low']
    pivot_highs = []
    pivot_lows = []
    for i in range(left, len(df) - right):
        if highs.iloc[i] == max(highs.iloc[i-left:i+right+1]):
            pivot_highs.append(i)
        if lows.iloc[i] == min(lows.iloc[i-left:i+right+1]):
            pivot_lows.append(i)
    return pivot_highs, pivot_lows

# === Helper: Structure+EMA trend detection ===
def detect_trend_4h_1h(df_4h, df_1h):
    # Structure: HH/HL for uptrend, LL/LH for downtrend
    ph_4h, pl_4h = find_swings_pivots(df_4h)
    ph_1h, pl_1h = find_swings_pivots(df_1h)
    trend = "RANGE"
    conf = 0
    # 4H structure
    if len(ph_4h) >= 2 and len(pl_4h) >= 2:
        last_highs = [df_4h['high'].iloc[ph_4h[-2]], df_4h['high'].iloc[ph_4h[-1]]]
        last_lows = [df_4h['low'].iloc[pl_4h[-2]], df_4h['low'].iloc[pl_4h[-1]]]
        if last_highs[1] > last_highs[0] and last_lows[1] > last_lows[0]:
            trend = "UP"
            conf += 1
        elif last_highs[1] < last_highs[0] and last_lows[1] < last_lows[0]:
            trend = "DOWN"
            conf += 1
    # 1H structure
    if len(ph_1h) >= 2 and len(pl_1h) >= 2:
        last_highs = [df_1h['high'].iloc[ph_1h[-2]], df_1h['high'].iloc[ph_1h[-1]]]
        last_lows = [df_1h['low'].iloc[pl_1h[-2]], df_1h['low'].iloc[pl_1h[-1]]]
        if last_highs[1] > last_highs[0] and last_lows[1] > last_lows[0]:
            if trend == "UP":
                conf += 1
            else:
                trend = "RANGE"
        elif last_highs[1] < last_highs[0] and last_lows[1] < last_lows[0]:
            if trend == "DOWN":
                conf += 1
            else:
                trend = "RANGE"
    # EMA filter (1H)
    ema_fast = ema(df_1h['close'], EMA_FAST)
    ema_slow = ema(df_1h['close'], EMA_SLOW)
    if trend == "UP" and ema_fast.iloc[-1] > ema_slow.iloc[-1]:
        conf += 1
    elif trend == "DOWN" and ema_fast.iloc[-1] < ema_slow.iloc[-1]:
        conf += 1
    else:
        trend = "RANGE"
    return trend, conf

# === Helper: Confirm HL/LH after pullback ===
def confirm_hl_lh(df, trend, pivots):
    ph, pl = pivots
    if trend == "UP" and len(pl) >= 2:
        hl1, hl2 = pl[-2], pl[-1]
        if df['low'].iloc[hl2] > df['low'].iloc[hl1]:
            return True, hl2
    if trend == "DOWN" and len(ph) >= 2:
        lh1, lh2 = ph[-2], ph[-1]
        if df['high'].iloc[lh2] < df['high'].iloc[lh1]:
            return True, lh2
    return False, None

# === Helper: Entry trigger on lower TF ===
def entry_trigger_lower_tf(df, trend):
    # Simple bullish/bearish engulfing or strong close
    if len(df) < 2:
        return False
    if trend == "UP":
        return df['close'].iloc[-1] > df['open'].iloc[-1] and df['close'].iloc[-1] > df['high'].iloc[-2]
    if trend == "DOWN":
        return df['close'].iloc[-1] < df['open'].iloc[-1] and df['close'].iloc[-1] < df['low'].iloc[-2]
    return False
# =========================
# STRATEGY HELPERS (shared)


# =========================
    """
    Kontrollon sinjalet e hapura nëse preket TP/SL dhe i mbyll automatikisht.
    """
    with open_signals_lock:
        to_close = []
        for signal_id, sig in open_signals.items():
            if sig["status"] != "open":
                continue
            symbol = sig["symbol"]
            direction = sig["direction"]
            sl = sig["sl"]
            tp = sig["tp"]
            # Merr çmimin aktual
            try:
                df = fetch_ohlc(symbol, TF_ENTRY, 1)
                if df.empty:
                    continue
                price = df['close'].iloc[-1]
                close_type = None
                if direction == "BUY":
                    if price <= sl:
                        close_type = "sl"
                    elif price >= tp:
                        close_type = "tp"
                else:
                    if price >= sl:
                        close_type = "sl"
                    elif price <= tp:
                        close_type = "tp"
                if close_type:
                    to_close.append((signal_id, close_type, price))
            except Exception as e:
                print(f"[AUTO-CLOSE] Error checking {symbol}: {e}")
        # Mbyll sinjalet që kanë prekur TP/SL
        for signal_id, close_type, price in to_close:
            try:
                resp = requests.post(f"{BACKEND_URL}/{signal_id}/close", json={
                    "hit": close_type,
                    "pnl_percent": None
                }, timeout=5)
                if resp.ok:
                    print(f"[AUTO-CLOSE] Signal {signal_id} closed ({close_type}) at price={price}")
                    open_signals[signal_id]["status"] = "closed"
                else:
                    print(f"[AUTO-CLOSE] Error closing signal {signal_id}: {resp.status_code} {resp.text}")
            except Exception as e:
                print(f"[AUTO-CLOSE] Exception closing signal {signal_id}: {e}")
def ema(series, length):
    return series.ewm(span=length, adjust=False).mean()

def trend_by_ema(df, ema_len=200):
    ema_val = ema(df['Close'], ema_len)
    last_close = df['Close'].iloc[-1]
    last_ema = ema_val.iloc[-1]
    if last_close > last_ema:
        return "UP"
    elif last_close < last_ema:
        return "DOWN"
    else:
        return "FLAT"

def pullback_touched(df, direction, ema_len=50):
    ema_val = ema(df['Close'], ema_len)
    if direction == "UP":
        return (df['Close'] < ema_val).iloc[-10:].any()
    elif direction == "DOWN":
        return (df['Close'] > ema_val).iloc[-10:].any()
    return False

def detect_pivots(df, left=2, right=2):
    highs = df['High']
    lows = df['Low']
    pivot_highs = []
    pivot_lows = []
    for i in range(left, len(df) - right):
        if highs.iloc[i] == max(highs.iloc[i-left:i+right+1]):
            pivot_highs.append(i)
        if lows.iloc[i] == min(lows.iloc[i-left:i+right+1]):
            pivot_lows.append(i)
    return pivot_highs, pivot_lows

def hl_lh_bos_trigger(df, direction, left=2, right=2):
    pivot_highs, pivot_lows = detect_pivots(df, left, right)
    if direction == "UP" and len(pivot_lows) >= 2:
        hl1, hl2 = pivot_lows[-2], pivot_lows[-1]
        if df['Low'].iloc[hl2] > df['Low'].iloc[hl1]:
            # BOS up: price breaks above last pivot high after HL
            for ph in reversed(pivot_highs):
                if ph > hl2:
                    if df['Close'].iloc[-1] > df['High'].iloc[ph]:
                        entry = df['Close'].iloc[-1]
                        sl = df['Low'].iloc[hl2] * 0.999
                        return True, entry, sl
                    break
    if direction == "DOWN" and len(pivot_highs) >= 2:
        lh1, lh2 = pivot_highs[-2], pivot_highs[-1]
        if df['High'].iloc[lh2] < df['High'].iloc[lh1]:
            # BOS down: price breaks below last pivot low after LH
            for pl in reversed(pivot_lows):
                if pl > lh2:
                    if df['Close'].iloc[-1] < df['Low'].iloc[pl]:
                        entry = df['Close'].iloc[-1]
                        sl = df['High'].iloc[lh2] * 1.001
                        return True, entry, sl
                    break
    return False, None, None
import time
from datetime import datetime, timedelta, timezone
from typing import Dict, Tuple, Optional

import numpy as np
import pandas as pd
import yfinance as yf
import requests
import traceback

# ======================================================
#                     CONFIG
# ======================================================

# URL i backend-it FastAPI â€“ PERDOR PORTIN 8000
BACKEND_URL = "http://127.0.0.1:8000/signals"   # endpoint kryesor i sinjaleve
ADMIN_API_BASE = "http://127.0.0.1:8000"        # pÃ«r /admin/bot_... endpoint-et

# Identifikimi i kÃ«tij boti (pÃ«r admin panel / system status)
BOT_ID = "forex_scalper_bot"

# KÃ«to pÃ«rdoren nÃ« app
SOURCE_NAME = "forex_scalper_bot"
ANALYSIS_TYPE = "forex_intraday"  # Forex Scalping -> Forex Intraday (app expects this)  # lidhet me filtrin Forex Scalping nÃ« app

# Forex pairs
SYMBOLS = [
    "EURUSD=X", "GBPUSD=X", "AUDUSD=X", "NZDUSD=X", "USDCAD=X",
    "USDCHF=X", "USDJPY=X", "EURGBP=X", "EURAUD=X", "EURNZD=X",
    "EURCAD=X", "EURCHF=X", "EURJPY=X", "GBPAUD=X", "GBPNZD=X",
    "GBPCAD=X", "GBPCHF=X", "GBPJPY=X", "AUDNZD=X", "AUDCAD=X",
    "AUDCHF=X", "AUDJPY=X", "NZDCAD=X", "NZDCHF=X", "NZDJPY=X",
    "CADCHF=X", "CADJPY=X", "CHFJPY=X"
]
    from datetime import datetime  # Ensure datetime is imported for new factors


INTERVAL = "5m"         # Scalping TF
LOOKBACK_DAYS = 3       # Sa ditÃ« mbrapa pÃ«r 5m
SLEEP_SECONDS = 60      # Sa sekonda pushim mes skanimeve

SL_PERCENT = 0.01  # 1% stop loss
TP_PERCENT = 0.03  # 3% take profit

# Minimum Risk/Reward ratio
MIN_RISK_REWARD = 1.8

# ADX threshold
MIN_ADX_STRENGTH = 20

# Volume threshold
MIN_VOLUME_RATIO = 1.3

# Scoring - kÃ«rkojmÃ« 4 nga 6 konfirmime
MIN_SCORE_FOR_SIGNAL = 4

# Minimum distancÃ« mes sinjaleve pÃ«r tÃ« njÃ«jtin simbol & drejtim
MIN_MINUTES_BETWEEN_SIGNALS = 30

# Memoria e sinjalit tÃ« fundit
last_signal_time: Dict[Tuple[str, str], datetime] = {}  # (symbol, side) -> time

# Heartbeat config
HEARTBEAT_INTERVAL = 300  # 5 minuta
last_heartbeat_ts: float = 0.0


# ======================================================
#              BACKEND: SEND SIGNAL
# ======================================================

def send_signal_to_backend(
    symbol: str,
    direction: str,
    timeframe: str,
    entry: float,
    sl: float,
    tp: float,
    extra_text: str = "",
):
    """
    DÃ«rgon sinjal te FastAPI (tabela signals).
    """
    payload = {
        "symbol": symbol.replace("=X", "") if symbol.endswith("=X") else symbol,
        "direction": direction.upper(),
        "entry": float(entry),
        "tp": float(tp),
        "sl": float(sl),
        "time": datetime.now(timezone.utc).isoformat(),
        "timeframe": timeframe,
        "source": SOURCE_NAME,
        "analysis_type": ANALYSIS_TYPE,
        "status": "open",
        "extra_text": extra_text,
    }

    try:
        resp = requests.post(BACKEND_URL, json=payload, timeout=5)
        if not resp.ok:
            print(f"[BACKEND] âŒ Error {resp.status_code}: {resp.text}")
        else:
            data = resp.json()
            print(
                f"[BACKEND] âœ… Signal saved (id={data.get('id')}): "
                f"{symbol} {direction} {timeframe} "
                f"E={entry:.4f} SL={sl:.4f} TP={tp:.4f}"
            )
    except Exception as e:
        print(f"[BACKEND] Exception sending signal: {e}")


# ======================================================
#                 ADMIN MONITORING
# ======================================================

def send_heartbeat():
    """
    DÃ«rgon njÃ« heartbeat te backend qÃ« admini tÃ« shohÃ« qÃ« boti Ã«shtÃ« gjallÃ«.
    """
    try:
        payload = {
            "bot_id": BOT_ID,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        resp = requests.post(
            f"{ADMIN_API_BASE}/admin/bot_heartbeat",
            json=payload,
            timeout=5,
        )
        if not resp.ok:
            print(f"[HEARTBEAT] âŒ {resp.status_code}: {resp.text}")
        else:
            print(f"[HEARTBEAT] âœ… {BOT_ID}")
    except Exception as e:
        print(f"[HEARTBEAT] ERROR: {e}")


def notify_signal_sent(symbol: str, direction: str):
    """
    Njofton backend-in se ky bot ka dÃ«rguar sinjal.
    PÃ«rdoret pÃ«r /admin/bot_signal dhe pÃ«r System status nÃ« app.
    """
    try:
        payload = {
            "bot_id": BOT_ID,
            "symbol": symbol,
            "direction": direction.upper(),
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }
        resp = requests.post(
            f"{ADMIN_API_BASE}/admin/bot_signal",
            json=payload,
            timeout=5,
        )
        if not resp.ok:
            print(f"[BOT_SIGNAL_LOG] âŒ {resp.status_code}: {resp.text}")
        else:
            print(f"[BOT_SIGNAL_LOG] âœ… {symbol} {direction}")
    except Exception as e:
        print(f"[BOT_SIGNAL_LOG] ERROR: {e}")


# ======================================================
#                   DATA FETCHING
# ======================================================

def fetch_ohlc(symbol: str, interval: str = "5m", lookback_days: int = 3) -> pd.DataFrame:
    """
    Merr OHLC nga yfinance pÃ«r simbolin dhe intervalin e dhÃ«nÃ«.
    """
    try:
        end = datetime.now(timezone.utc)
        start = end - timedelta(days=lookback_days + 1)

        df = yf.download(
            symbol,
            start=start,
            end=end,
            interval=interval,
            auto_adjust=False,
            progress=False
        )
        if df is None or df.empty:
            print(f"[{symbol}] No data for interval={interval}")
            return pd.DataFrame()

        df = df[["Open", "High", "Low", "Close", "Volume"]].dropna()

        if not isinstance(df.index, pd.DatetimeIndex):
            df.index = pd.to_datetime(df.index)

        df = df.sort_index()
        return df

    except Exception:
        print(f"[{symbol}] Exception in fetch_ohlc(interval={interval}):")
        traceback.print_exc()
        return pd.DataFrame()


# ======================================================
#              SWINGS & TREND (HH, HL, LH, LL)
# ======================================================

def calculate_atr(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """
    Llogarit ATR (Average True Range).
    """
    high = df['High']
    low = df['Low']
    close = df['Close']
    
    tr1 = high - low
    tr2 = abs(high - close.shift())
    tr3 = abs(low - close.shift())
    
    tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
    atr = tr.ewm(span=period, adjust=False).mean()
    
    return atr


def calculate_adx(df: pd.DataFrame, period: int = 14) -> float:
    """
    Llogarit ADX.
    """
    high = df['High'].values
    low = df['Low'].values
    close = df['Close'].values
    
    if len(df) < period + 1:
        return 0.0
    
    plus_dm = np.zeros(len(df))
    minus_dm = np.zeros(len(df))
    
    for i in range(1, len(df)):
        high_diff = high[i] - high[i-1]
        low_diff = low[i-1] - low[i]
        
        if high_diff > low_diff and high_diff > 0:
            plus_dm[i] = high_diff
        if low_diff > high_diff and low_diff > 0:
            minus_dm[i] = low_diff
    
    atr = calculate_atr(df, period).values
    
    plus_di = 100 * pd.Series(plus_dm).ewm(span=period, adjust=False).mean() / (atr + 0.00001)
    minus_di = 100 * pd.Series(minus_dm).ewm(span=period, adjust=False).mean() / (atr + 0.00001)
    
    dx = 100 * abs(plus_di - minus_di) / (plus_di + minus_di + 0.00001)
    adx = dx.ewm(span=period, adjust=False).mean()
    
    return float(adx.iloc[-1]) if len(adx) > 0 else 0.0


def check_ema_alignment(df: pd.DataFrame) -> str:
    """
    Kontrollon alignment të EMA 8, 21, 50 për trend confirmation.
    Returns: "bull", "bear", or "neutral"
    """
    if len(df) < 50:
        return "neutral"
    
    ema8 = float(df['Close'].ewm(span=8, adjust=False).mean().iloc[-1])
    ema21 = float(df['Close'].ewm(span=21, adjust=False).mean().iloc[-1])
    ema50 = float(df['Close'].ewm(span=50, adjust=False).mean().iloc[-1])
    
    # Bullish alignment: EMA8 > EMA21 > EMA50
    if ema8 > ema21 > ema50:
        return "bull"
    # Bearish alignment: EMA8 < EMA21 < EMA50
    elif ema8 < ema21 < ema50:
        return "bear"
    else:
        return "neutral"


def calculate_macd(df: pd.DataFrame, fast=12, slow=26, signal=9) -> tuple:
    """
    Llogarit MACD (Moving Average Convergence Divergence).
    Returns: (macd_line, signal_line, histogram, bullish_cross, bearish_cross)
    """
    if len(df) < slow + signal:
        return 0.0, 0.0, 0.0, False, False
    
    ema_fast = df['Close'].ewm(span=fast, adjust=False).mean()
    ema_slow = df['Close'].ewm(span=slow, adjust=False).mean()
    macd_line = ema_fast - ema_slow
    signal_line = macd_line.ewm(span=signal, adjust=False).mean()
    histogram = macd_line - signal_line
    
    bullish_cross = False
    bearish_cross = False
    
    if len(histogram) >= 2:
        if float(histogram.iloc[-2]) < 0 and float(histogram.iloc[-1]) > 0:
            bullish_cross = True
        elif float(histogram.iloc[-2]) > 0 and float(histogram.iloc[-1]) < 0:
            bearish_cross = True
    
    return float(macd_line.iloc[-1]), float(signal_line.iloc[-1]), float(histogram.iloc[-1]), bullish_cross, bearish_cross


def calculate_stochastic(df: pd.DataFrame, period=14, smooth_k=3, smooth_d=3) -> tuple:
    """
    Llogarit Stochastic Oscillator (%K dhe %D).
    Returns: (k_value, d_value, oversold_cross_up, overbought_cross_down)
    """
    if len(df) < period + smooth_k + smooth_d:
        return 50.0, 50.0, False, False
    
    low_min = df['Low'].rolling(window=period).min()
    high_max = df['High'].rolling(window=period).max()
    
    k = 100 * (df['Close'] - low_min) / (high_max - low_min + 0.00001)
    k_smooth = k.rolling(window=smooth_k).mean()
    d = k_smooth.rolling(window=smooth_d).mean()
    
    oversold_cross_up = False
    overbought_cross_down = False
    
    if len(k_smooth) >= 2 and len(d) >= 2:
        k_curr = float(k_smooth.iloc[-1])
        k_prev = float(k_smooth.iloc[-2])
        d_curr = float(d.iloc[-1])
        d_prev = float(d.iloc[-2])
        
        if k_prev < d_prev and k_curr > d_curr and d_curr < 30:
            oversold_cross_up = True
        elif k_prev > d_prev and k_curr < d_curr and d_curr > 70:
            overbought_cross_down = True
    
    return float(k_smooth.iloc[-1]), float(d.iloc[-1]), oversold_cross_up, overbought_cross_down


def find_support_resistance_levels(df: pd.DataFrame, lookback: int = 100, num_levels: int = 3) -> tuple:
    """
    Gjen nivelet kryesore tÃ« S/R.
    """
    if df.empty or len(df) < lookback:
        return [], []
    
    recent_df = df.iloc[-lookback:]
    highs = recent_df['High'].values
    lows = recent_df['Low'].values
    
    resistance_levels = []
    support_levels = []
    
    for i in range(5, len(recent_df) - 5):
        if highs[i] == max(highs[i-5:i+6]):
            resistance_levels.append(highs[i])
        
        if lows[i] == min(lows[i-5:i+6]):
            support_levels.append(lows[i])
    
    def cluster_levels(levels):
        if not levels:
            return []
        levels = sorted(levels)
        clustered = []
        current_cluster = [levels[0]]
        
        for level in levels[1:]:
            if abs(level - current_cluster[-1]) / current_cluster[-1] < 0.005:
                current_cluster.append(level)
            else:
                clustered.append(np.mean(current_cluster))
                current_cluster = [level]
        clustered.append(np.mean(current_cluster))
        return clustered[-num_levels:]
    
    return cluster_levels(support_levels), cluster_levels(resistance_levels)


def is_near_sr_level(price: float, levels: list, tolerance: float = 0.008) -> bool:
    """
    Kontrollon nÃ«se Ã§mimi Ã«shtÃ« afÃ«r S/R.
    """
    for level in levels:
        if abs(price - level) / level <= tolerance:
            return True
    return False


def detect_rsi_divergence(df: pd.DataFrame, rsi_period: int = 14, lookback: int = 20) -> tuple:
    """
    Detekton RSI divergence.
    """
    if df.empty or len(df) < rsi_period + lookback:
        return False, False
    
    close = df['Close']
    delta = close.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=rsi_period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=rsi_period).mean()
    rs = gain / (loss + 0.00001)
    rsi = 100 - (100 / (1 + rs))
    
    recent_df = df.iloc[-lookback:].copy()
    recent_rsi = rsi.iloc[-lookback:].values
    recent_price = recent_df['Close'].values
    
    bullish_div = False
    bearish_div = False
    
    for i in range(5, len(recent_df) - 2):
        if i > 10:
            if recent_price[i] < recent_price[i-10]:
                if recent_rsi[i] > recent_rsi[i-10]:
                    bullish_div = True
            
            if recent_price[i] > recent_price[i-10]:
                if recent_rsi[i] < recent_rsi[i-10]:
                    bearish_div = True
    
    return bullish_div, bearish_div


def find_swings(df: pd.DataFrame, lookback: int = 3):
    """
    Gjen indekset e swing high & swing low nÃ« njÃ« seri.
    """
    highs = df["High"].values
    lows = df["Low"].values

    swing_high_idx = []
    swing_low_idx = []

    for i in range(lookback, len(df) - lookback):
        window_highs = highs[i - lookback:i + lookback + 1]
        window_lows = lows[i - lookback:i + lookback + 1]

        if highs[i] == window_highs.max() and highs[i] > window_highs.mean():
            swing_high_idx.append(i)
        if lows[i] == window_lows.min() and lows[i] < window_lows.mean():
            swing_low_idx.append(i)

    return np.array(swing_high_idx), np.array(swing_low_idx)


def classify_trend(df: pd.DataFrame) -> Tuple[str, Optional[int], Optional[int], Optional[int], Optional[int]]:
    """
    Kthen:
      trend: "bull" / "bear" / "choppy"
      idx_last_high1, idx_last_high2, idx_last_low1, idx_last_low2
    ku 1 = mÃ« i vjetri, 2 = mÃ« i riu.
    """
    if df.empty or len(df) < 40:
        return "choppy", None, None, None, None

    swing_high_idx, swing_low_idx = find_swings(df, lookback=2)
    if len(swing_high_idx) < 2 or len(swing_low_idx) < 2:
        return "choppy", None, None, None, None

    last_two_highs = swing_high_idx[-2:]
    last_two_lows = swing_low_idx[-2:]

    h1_idx, h2_idx = last_two_highs
    l1_idx, l2_idx = last_two_lows

    h1 = float(df["High"].iloc[h1_idx])
    h2 = float(df["High"].iloc[h2_idx])
    l1 = float(df["Low"].iloc[l1_idx])
    l2 = float(df["Low"].iloc[l2_idx])

    # Bullish: HH + HL
    if h2 > h1 and l2 >= l1:
        return "bull", h1_idx, h2_idx, l1_idx, l2_idx

    # Bearish: LH + LL
    if h2 <= h1 and l2 < l1:
        return "bear", h1_idx, h2_idx, l1_idx, l2_idx

    return "choppy", h1_idx, h2_idx, l1_idx, l2_idx


def compute_ema(series: pd.Series, period: int = 20) -> pd.Series:
    return series.ewm(span=period, adjust=False).mean()


# ======================================================
#                    SIGNAL LOGIC
# ======================================================

def analyze_symbol(symbol: str):
    # 1. Get data
    df_4h = fetch_ohlc(symbol, TF_4H, LOOKBACK_BARS)
    df_1h = fetch_ohlc(symbol, TF_1H, LOOKBACK_BARS)
    df_entry = fetch_ohlc(symbol, TF_ENTRY, LOOKBACK_BARS)
    if df_4h.empty or df_1h.empty or df_entry.empty:
        print(f"[{symbol}] Skipped: insufficient data.")
        return

    # 2. Trend detection
    trend, conf = detect_trend_4h_1h(df_4h, df_1h)
    if trend not in ("UP", "DOWN") or conf < 2:
        print(f"[{symbol}] Skipped: trend not strong (trend={trend}, conf={conf})")
        return

    # 3. Pullback to EMA zone
    ema_fast = ema(df_1h['close'], EMA_FAST)
    ema_slow = ema(df_1h['close'], EMA_SLOW)
    price = df_1h['close'].iloc[-1]
    in_zone = (ema_fast.iloc[-1] <= price <= ema_slow.iloc[-1]) or (ema_slow.iloc[-1] <= price <= ema_fast.iloc[-1])
    if not in_zone:
        print(f"[{symbol}] Skipped: no pullback to EMA zone.")
        return

    # 4. Confirm HL/LH on 1H
    pivots = find_swings_pivots(df_1h)
    hl_lh_ok, pivot_idx = confirm_hl_lh(df_1h, trend, pivots)
    if not hl_lh_ok:
        print(f"[{symbol}] Skipped: no HL/LH confirmation.")
        return

    # 5. Trigger candle on lower TF
    trigger = entry_trigger_lower_tf(df_entry, trend)
    if not trigger:
        print(f"[{symbol}] Skipped: no trigger candle on {TF_ENTRY}.")
        return

    # 6. Entry/SL/TP
    entry = df_entry['close'].iloc[-1]
    if trend == "UP":
        sl = df_1h['low'].iloc[pivot_idx] * 0.999
        tp = entry + RR * abs(entry - sl)
    else:
        sl = df_1h['high'].iloc[pivot_idx] * 1.001
        tp = entry - RR * abs(entry - sl)

    # 7. Send signal
    debug_info = f"trend={trend}, conf={conf}, pullback_zone={in_zone}, HL_LH={hl_lh_ok}, trigger={trigger}"
    extra = f"StructureScalp | {debug_info}"
    send_signal_to_backend(
        symbol=symbol,
        direction="BUY" if trend == "UP" else "SELL",
        timeframe=TF_ENTRY,
        entry=entry,
        sl=sl,
        tp=tp,
        extra_text=extra,
    )
    notify_signal_sent(symbol, "BUY" if trend == "UP" else "SELL")
    print(f"[{symbol}] Signal sent: {trend} | entry={entry:.4f} sl={sl:.4f} tp={tp:.4f} | {debug_info}")


# ======================================================
#                    MAIN LOOP
# ======================================================

def main_loop():
    global last_heartbeat_ts

    print("ðŸš€ Forex SCALP bot started.")
    print(f"Source: {SOURCE_NAME}")
    print(f"Analysis type: {ANALYSIS_TYPE}")
    print(f"Symbols: {len(SYMBOLS)} (Forex)")
    print(f"Timeframe: {INTERVAL}, scan every {SLEEP_SECONDS} seconds.\n")

    # Heartbeat fillestar
    send_heartbeat()
    last_heartbeat_ts = time.time()

    while True:
        now_ts = time.time()

        # Heartbeat periodik
        if now_ts - last_heartbeat_ts > HEARTBEAT_INTERVAL:
            send_heartbeat()
            last_heartbeat_ts = now_ts

        for symbol in SYMBOLS:
            try:
                analyze_symbol(symbol)
            except Exception:
                print(f"[{symbol}] Exception in analyze_symbol:")
                traceback.print_exc()
            try:
                check_and_close_signals()
            except Exception as e:
                print(f"[AUTO-CLOSE] Exception in check_and_close_signals: {e}")
        print(f"Sleeping {SLEEP_SECONDS} seconds...\n")
        time.sleep(SLEEP_SECONDS)


if __name__ == "__main__":
    try:
        main_loop()
    except Exception:
        print("\nâŒ KISHTE NJÃ‹ GABIM NÃ‹ PROGRAM:")
        traceback.print_exc()
        input("\nShtyp ENTER qÃ« tÃ« mbyllet dritarja...")
