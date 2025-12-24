import time
from datetime import datetime, timedelta, timezone
from typing import Optional, Tuple, Dict

import pandas as pd
import numpy as np
import yfinance as yf
import requests
import traceback
from zoneinfo import ZoneInfo
import warnings

# Fik vetÃ«m FutureWarning nga yfinance
warnings.filterwarnings("ignore", category=FutureWarning, module="yfinance")

# ======================================================
#                     CONFIG
# ======================================================

# Backend FastAPI â€“ PERDOR PORTIN 8000
BACKEND_URL = "http://127.0.0.1:8000/signals"
ADMIN_API_BASE = "http://127.0.0.1:8000"   # pÃ«r admin endpointet

# Ky do pÃ«rdoret si "source" nÃ« app
SOURCE_NAME = "forex_swing_bot"
ANALYSIS_TYPE = "forex_swing"   # lidhet me filtrin nÃ« app

# ID e botit pÃ«r system-status nÃ« backend
BOT_ID = "forex_swing_bot"

# Telegram (opsionale, nÃ«se do sinjale edhe aty)
TELEGRAM_BOT_TOKEN = "8250059370:AAGRq5rNcjqaAO4iqQk4A2q4ADBPnPAE-Nw"
TELEGRAM_CHAT_IDS = [802744614]

# Forex pairs (mund t'i ndryshosh si tÃ« duash)
SYMBOLS = [
    "EURUSD=X", "GBPUSD=X", "AUDUSD=X", "NZDUSD=X", "USDCAD=X",
    "USDCHF=X", "USDJPY=X", "EURGBP=X", "EURAUD=X", "EURNZD=X",
    "EURCAD=X", "EURCHF=X", "EURJPY=X", "GBPAUD=X", "GBPNZD=X",
    "GBPCAD=X", "GBPCHF=X", "GBPJPY=X", "AUDNZD=X", "AUDCAD=X",
    "AUDCHF=X", "AUDJPY=X", "NZDCAD=X", "NZDCHF=X", "NZDJPY=X",
    "CADCHF=X", "CADJPY=X", "CHFJPY=X"
]

LOCAL_TZ = ZoneInfo("Europe/Belgrade")

LOOKBACK_DAYS_D1 = 180     # sa ditÃ« mbrapa pÃ«r D1
LOOKBACK_DAYS_4H = 60      # sa ditÃ« mbrapa pÃ«r 1H/4H
SLEEP_SECONDS = 900        # 15 minuta pushim mes skanimeve

# Scoring - kÃ«rkojmÃ« 4 nga 7 konfirmime
MIN_SCORE_FOR_SIGNAL = 4

SL_PERCENT = 0.01  # 1% stop loss
TP_PERCENT = 0.03  # 3% take profit

# Minimum Risk/Reward ratio
MIN_RISK_REWARD = 2.0

# ADX threshold pÃ«r trend strength
MIN_ADX_STRENGTH = 20  # ulur nga 25 -> 20

# Volume confirmation threshold
MIN_VOLUME_RATIO = 1.2

# memoria e sinjalit tÃ« fundit pÃ«r Ã§do simbol (BUY/SELL)
last_signal_side: Dict[str, str] = {}
last_signal_time: Dict[str, datetime] = {}
MIN_MINUTES_BETWEEN_SIGNALS = 240  # minimum 4 orÃ« mes sinjaleve tÃ« njÃ«jta

# Heartbeat config
HEARTBEAT_INTERVAL = 300  # 5 minuta
last_heartbeat_ts: float = 0.0


# ======================================================
#                  TELEGRAM HELPERS
# ======================================================

def send_telegram_message(text: str):
    """DÃ«rgon mesazh nÃ« tÃ« gjithÃ« CHAT_ID-t."""
    if not TELEGRAM_BOT_TOKEN:
        return
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    for chat_id in TELEGRAM_CHAT_IDS:
        try:
            resp = requests.post(
                url,
                data={
                    "chat_id": chat_id,
                    "text": text,
                    "parse_mode": "HTML"
                },
                timeout=10
            )
            if not resp.ok:
                print(f"[TELEGRAM] Error: {resp.text}")
        except Exception as e:
            print(f"[TELEGRAM] Exception: {e}")


# ======================================================
#              ADMIN / MONITORING HELPERS
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
    Njofton backend-in se ky bot ka dÃ«rguar sinjal
    (pÃ«r statistika & system status te admini).
    """
    try:
        payload = {
            "bot_id": BOT_ID,
            "symbol": symbol.replace("=X", "") if symbol.endswith("=X") else symbol,
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
    DÃ«rgon sinjal te FastAPI...
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
#                   DATA FETCHING
# ======================================================

def fetch_ohlc(symbol: str, interval: str = "1h", lookback_days: int = 120) -> pd.DataFrame:
    """
    Merr OHLC nga yfinance pÃ«r simbolin dhe intervalin e dhÃ«nÃ«.
    """
    try:
        end = datetime.now(timezone.utc)
        start = end - timedelta(days=lookback_days + 5)

        df = yf.download(
            symbol,
            start=start,
            end=end,
            interval=interval,
            auto_adjust=False,
            progress=False,
            timeout=60  # rrit timeout pÃ«r forex symbols
        )
        if df is None or df.empty:
            # print(f"[{symbol}] No data for interval={interval}")
            return pd.DataFrame()

        # Hiq rreshtat me NaN dhe rregullo kolonat
        df = df[["Open", "High", "Low", "Close", "Volume"]].dropna()

        if not isinstance(df.index, pd.DatetimeIndex):
            df.index = pd.to_datetime(df.index)

        df = df.sort_index()
        return df

    except Exception as e:
        # Nuk printoj traceback për timeout, vetëm error message
        if "timeout" in str(e).lower() or "timed out" in str(e).lower():
            print(f"[{symbol}] ⏱️ Timeout: {interval} data")
        else:
            print(f"[{symbol}] Exception in fetch_ohlc(interval={interval}): {e}")
        return pd.DataFrame()


def resample_to_4h(h1: pd.DataFrame) -> pd.DataFrame:
    """
    Nga 1H -> 4H OHLC.
    """
    if h1.empty:
        return pd.DataFrame()

    df = h1.copy()
    df = df[~df.index.duplicated(keep="last")]

    df_4h = pd.DataFrame()
    df_4h["Open"] = df["Open"].resample("4h").first()
    df_4h["High"] = df["High"].resample("4h").max()
    df_4h["Low"] = df["Low"].resample("4h").min()
    df_4h["Close"] = df["Close"].resample("4h").last()
    df_4h["Volume"] = df["Volume"].resample("4h").sum()

    df_4h = df_4h.dropna()
    return df_4h


# ======================================================
#                D1 TREND DETECTION
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
    Llogarit ADX (Average Directional Index).
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
    
    # Check for crossover
    bullish_cross = False
    bearish_cross = False
    
    if len(histogram) >= 2:
        # Bullish: MACD crosses above signal
        if float(histogram.iloc[-2]) < 0 and float(histogram.iloc[-1]) > 0:
            bullish_cross = True
        # Bearish: MACD crosses below signal
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
    
    # %K = 100 * (Close - Low) / (High - Low)
    k = 100 * (df['Close'] - low_min) / (high_max - low_min + 0.00001)
    k_smooth = k.rolling(window=smooth_k).mean()
    d = k_smooth.rolling(window=smooth_d).mean()
    
    # Check for crossovers
    oversold_cross_up = False
    overbought_cross_down = False
    
    if len(k_smooth) >= 2 and len(d) >= 2:
        k_curr = float(k_smooth.iloc[-1])
        k_prev = float(k_smooth.iloc[-2])
        d_curr = float(d.iloc[-1])
        d_prev = float(d.iloc[-2])
        
        # Bullish: %K crosses above %D in oversold zone (<20)
        if k_prev < d_prev and k_curr > d_curr and d_curr < 30:
            oversold_cross_up = True
        # Bearish: %K crosses below %D in overbought zone (>80)
        elif k_prev > d_prev and k_curr < d_curr and d_curr > 70:
            overbought_cross_down = True
    
    return float(k_smooth.iloc[-1]), float(d.iloc[-1]), oversold_cross_up, overbought_cross_down


def check_volume_confirmation(df: pd.DataFrame, lookback: int = 20) -> tuple:
    """
    Kontrollon nÃ«se volume aktual Ã«shtÃ« mÃ« i lartÃ« se mesatarja.
    """
    if df.empty or len(df) < lookback:
        return False, 0.0
    
    recent_volumes = df['Volume'].iloc[-(lookback+1):-1]
    avg_volume = recent_volumes.mean()
    current_volume = df['Volume'].iloc[-1]
    
    if avg_volume == 0:
        return False, 0.0
    
    volume_ratio = current_volume / avg_volume
    is_high = volume_ratio >= MIN_VOLUME_RATIO
    
    return is_high, float(volume_ratio)


def find_support_resistance_levels(df: pd.DataFrame, lookback: int = 100, num_levels: int = 5) -> tuple:
    """
    Gjen nivelet kryesore tÃ« support dhe resistance.
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


def is_near_sr_level(price: float, levels: list, tolerance: float = 0.01) -> bool:
    """
    Kontrollon nÃ«se Ã§mimi Ã«shtÃ« afÃ«r njÃ« niveli S/R.
    """
    for level in levels:
        if abs(price - level) / level <= tolerance:
            return True
    return False


def detect_rsi_divergence(df: pd.DataFrame, rsi_period: int = 14, lookback: int = 30) -> tuple:
    """
    Detekton bullish dhe bearish divergence nÃ« RSI.
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
    
    for i in range(5, len(recent_df) - 5):
        if i > 10:
            if recent_price[i] < recent_price[i-10]:
                if recent_rsi[i] > recent_rsi[i-10]:
                    bullish_div = True
            
            if recent_price[i] > recent_price[i-10]:
                if recent_rsi[i] < recent_rsi[i-10]:
                    bearish_div = True
    
    return bullish_div, bearish_div


def detect_trend_d1(d1: pd.DataFrame) -> str:
    """
    Trend D1 nÃ« bazÃ« tÃ« EMA50 dhe EMA200.
    Kthen: "bull", "bear" ose "choppy".
    """
    if d1.empty or len(d1) < 220:
        return "choppy"

    close = d1["Close"]
    ema50 = close.ewm(span=50, adjust=False).mean()
    ema200 = close.ewm(span=200, adjust=False).mean()

    last_ema50 = float(ema50.iloc[-1])
    last_ema200 = float(ema200.iloc[-1])
    last_close = float(close.iloc[-1])

    if last_ema50 > last_ema200 and last_close > last_ema50:
        return "bull"
    elif last_ema50 < last_ema200 and last_close < last_ema50:
        return "bear"
    else:
        return "choppy"


# ======================================================
#              4H STRUCTURE (HH, HL, LH, LL)
# ======================================================

def _find_swings(df: pd.DataFrame, lookback: int = 3) -> Tuple[np.ndarray, np.ndarray]:
    """
    Gjen pika swing high dhe swing low.
    Kthen dy array me indekset e swing_high dhe swing_low.
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


def classify_structure(h4: pd.DataFrame) -> str:
    """
    Klasifikon strukturÃ«n 4H si "bull", "bear", ose "choppy".
    """
    if h4.empty or len(h4) < 30:
        return "choppy"

    swing_high_idx, swing_low_idx = _find_swings(h4, lookback=2)
    if len(swing_high_idx) < 2 or len(swing_low_idx) < 2:
        return "choppy"

    # Mer dy high & dy low tÃ« fundit
    last_two_highs = swing_high_idx[-2:]
    last_two_lows = swing_low_idx[-2:]

    h1_idx, h2_idx = last_two_highs
    l1_idx, l2_idx = last_two_lows

    h1 = float(h4["High"].iloc[h1_idx])
    h2 = float(h4["High"].iloc[h2_idx])
    l1 = float(h4["Low"].iloc[l1_idx])
    l2 = float(h4["Low"].iloc[l2_idx])

    # Bullish: HH & HL
    if h2 > h1 and l2 >= l1:
        return "bull"
    # Bearish: LH & LL
    if h2 <= h1 and l2 < l1:
        return "bear"

    return "choppy"


# ======================================================
#           ORDER BLOCK (shumÃ« i thjeshtuar)
# ======================================================

def find_recent_order_block(df: pd.DataFrame, direction: str, lookback: int = 40) -> Optional[Tuple[float, float, float]]:
    """
    Gjen njÃ« order block tÃ« fundit me strength scoring.
    Kthen (low, high, strength).
    """
    if df.empty or len(df) < lookback + 5:
        return None

    sub = df.iloc[-(lookback + 5):]
    closes = sub["Close"].values
    opens = sub["Open"].values
    highs = sub["High"].values
    lows = sub["Low"].values
    volumes = sub["Volume"].values

    best_ob = None
    best_strength = 0.0

    for i in range(5, len(sub) - 4):
        candle_open = opens[i]
        candle_close = closes[i]
        candle_high = highs[i]
        candle_low = lows[i]
        candle_volume = volumes[i]
        candle_body = abs(candle_close - candle_open)
        
        avg_volume = np.mean(volumes[max(0, i-20):i]) if i > 20 else np.mean(volumes[:i])

        if direction == "bull":
            if candle_close <= candle_open:
                continue
            
            body_ratio = candle_body / (candle_high - candle_low + 0.00001)
            if body_ratio < 0.6:
                continue

            prev1_close = closes[i - 1]
            prev2_close = closes[i - 2]
            if not (prev1_close < prev2_close):
                continue
            
            volume_ratio = candle_volume / (avg_volume + 0.00001)
            if volume_ratio < 1.1:
                continue

            next_low = sub["Low"].iloc[i + 1:i + 4].min() if i + 4 < len(sub) else sub["Low"].iloc[i + 1:].min()
            if next_low <= candle_low * 0.997:
                strength = min(100, volume_ratio * 30 + body_ratio * 40 + 30)
                
                if strength > best_strength:
                    best_strength = strength
                    best_ob = (float(candle_low), float(candle_high), float(strength))

        elif direction == "bear":
            if candle_close >= candle_open:
                continue
            
            body_ratio = candle_body / (candle_high - candle_low + 0.00001)
            if body_ratio < 0.6:
                continue

            prev1_close = closes[i - 1]
            prev2_close = closes[i - 2]
            if not (prev1_close > prev2_close):
                continue
            
            volume_ratio = candle_volume / (avg_volume + 0.00001)
            if volume_ratio < 1.1:
                continue

            next_high = sub["High"].iloc[i + 1:i + 4].max() if i + 4 < len(sub) else sub["High"].iloc[i + 1:].max()
            if next_high >= candle_high * 1.003:
                strength = min(100, volume_ratio * 30 + body_ratio * 40 + 30)
                
                if strength > best_strength:
                    best_strength = strength
                    best_ob = (float(candle_low), float(candle_high), float(strength))

    return best_ob


# ======================================================
#                    FVG (3 candles)
# ======================================================

def has_recent_fvg(df: pd.DataFrame, direction: str, lookback: int = 20) -> bool:
    """
    FVG i thjeshtuar (3 candles).
    """
    if df.empty or len(df) < 5:
        return False

    sub = df.iloc[-(lookback + 2):]
    highs = sub["High"].values
    lows = sub["Low"].values

    for i in range(1, len(sub) - 1):
        if direction == "bull":
            if lows[i] > highs[i - 1]:
                return True
        elif direction == "bear":
            if highs[i] < lows[i - 1]:
                return True
    return False


# ======================================================
#                    SIGNAL LOGIC
# ======================================================

def analyze_symbol(symbol: str):
    global last_signal_side, last_signal_time

    d1 = fetch_ohlc(symbol, interval="1d", lookback_days=LOOKBACK_DAYS_D1)
    if d1.empty:
        # print(f"[{symbol}] No D1 data.")
        return

    trend_d1 = detect_trend_d1(d1)

    h1 = fetch_ohlc(symbol, interval="1h", lookback_days=LOOKBACK_DAYS_4H)
    if h1.empty:
        # print(f"[{symbol}] No H1 data.")
        return

    h4 = resample_to_4h(h1)
    if h4.empty or len(h4) < 30:
        # print(f"[{symbol}] Not enough 4H data.")
        return

    structure_4h = classify_structure(h4)
    current_price = float(h4["Close"].iloc[-1])
    
    # ===== ANALYTICAL INDICATORS =====
    # ATR pÃ«r dynamic SL/TP
    atr = calculate_atr(h4, period=14)
    current_atr = float(atr.iloc[-1]) if len(atr) > 0 else 0.0
    
    # ADX për trend strength
    adx_value = calculate_adx(h4, period=14)
    
    # EMA Alignment (NEW - 8th factor)
    ema_alignment = check_ema_alignment(h4)
    
    # Volume confirmation
    high_volume, volume_ratio = check_volume_confirmation(h4, lookback=20)
    
    # Support/Resistance levels
    support_levels, resistance_levels = find_support_resistance_levels(h4, lookback=100)
    
    # RSI Divergence
    bullish_div, bearish_div = detect_rsi_divergence(h4, rsi_period=14, lookback=40)
    
    bull_ob = find_recent_order_block(h4, direction="bull")
    bear_ob = find_recent_order_block(h4, direction="bear")
    bull_fvg = has_recent_fvg(h4, direction="bull")
    bear_fvg = has_recent_fvg(h4, direction="bear")
    
    # ATR check
    if current_atr == 0.0 or current_atr < current_price * 0.0001:
        # print(f"[{symbol}] ATR shumÃ« i ulÃ«t, skip.")
        return

    # ===== SCORE BUY / SELL (10 pika tani!) =====
    buy_score = 0
    sell_score = 0
    buy_details = []
    sell_details = []

    # 9) MACD Crossover
    macd_line, signal_line, histogram, macd_bull_cross, macd_bear_cross = calculate_macd(h4)
    if macd_bull_cross:
        buy_score += 1
        buy_details.append("MACD_CROSS")
    if macd_bear_cross:
        sell_score += 1
        sell_details.append("MACD_CROSS")

    # 10) Stochastic
    k_val, d_val, stoch_oversold_cross, stoch_overbought_cross = calculate_stochastic(h4)
    if stoch_oversold_cross:
        buy_score += 1
        buy_details.append("STOCH_OVER")
    if stoch_overbought_cross:
        sell_score += 1
        sell_details.append("STOCH_OVER")
    
    # 1) D1 trend
    if trend_d1 == "bull":
        buy_score += 1
        buy_details.append("D1_BULL")
    elif trend_d1 == "bear":
        sell_score += 1
        sell_details.append("D1_BEAR")
    
    # 2) 4H strukturÃ«
    if structure_4h == "bull":
        buy_score += 1
        buy_details.append("4H_BULL")
    elif structure_4h == "bear":
        sell_score += 1
        sell_details.append("4H_BEAR")
    
    # 3) ADX - trend strength
    if adx_value >= MIN_ADX_STRENGTH:
        if trend_d1 == "bull":
            buy_score += 1
            buy_details.append(f"ADX_{adx_value:.1f}")
        elif trend_d1 == "bear":
            sell_score += 1
            sell_details.append(f"ADX_{adx_value:.1f}")
    
    # 4) Volume confirmation
    if high_volume:
        if trend_d1 == "bull" or structure_4h == "bull":
            buy_score += 1
            buy_details.append(f"VOL_{volume_ratio:.2f}x")
        if trend_d1 == "bear" or structure_4h == "bear":
            sell_score += 1
            sell_details.append(f"VOL_{volume_ratio:.2f}x")
    
    # 5) Order Block afÃ«r Ã§mimit
    if bull_ob is not None:
        ob_low, ob_high, ob_strength = bull_ob
        if ob_low <= current_price <= ob_high * 1.002:
            buy_score += 1
            buy_details.append(f"OB_{ob_strength:.0f}%")
    if bear_ob is not None:
        ob_low, ob_high, ob_strength = bear_ob
        if ob_low * 0.998 <= current_price <= ob_high:
            sell_score += 1
            sell_details.append(f"OB_{ob_strength:.0f}%")
    
    # 6) FVG
    if bull_fvg:
        buy_score += 1
        buy_details.append("FVG_BULL")
    if bear_fvg:
        sell_score += 1
        sell_details.append("FVG_BEAR")
    
    # 7) RSI Divergence
    if bullish_div:
        buy_score += 1
        buy_details.append("RSI_DIV")
    if bearish_div:
        sell_score += 1
        sell_details.append("RSI_DIV")
    
    # 8) EMA Alignment
    if ema_alignment == "bull":
        buy_score += 1
        buy_details.append("EMA_ALIGNED")
    elif ema_alignment == "bear":
        sell_score += 1
        sell_details.append("EMA_ALIGNED")
    
    # 9) MACD Crossover
    macd_line, signal_line, histogram, macd_bull_cross, macd_bear_cross = calculate_macd(h4)
    if macd_bull_cross:
        buy_score += 1
        buy_details.append("MACD_CROSS")
    if macd_bear_cross:
        sell_score += 1
        sell_details.append("MACD_CROSS")
    
    # 10) Stochastic
    k_val, d_val, stoch_oversold_cross, stoch_overbought_cross = calculate_stochastic(h4)
    if stoch_oversold_cross:
        buy_score += 1
        buy_details.append("STOCH_OVER")
    if stoch_overbought_cross:
        sell_score += 1
        sell_details.append("STOCH_OVER")

    # ===== DECISION =====
    signal_side = None
    score_used = 0
    signal_details = []

    if buy_score >= MIN_SCORE_FOR_SIGNAL and buy_score >= sell_score:
        if is_near_sr_level(current_price, resistance_levels, tolerance=0.015):
            print(f"[{symbol}] BUY signal por afër resistance, SKIP.")
            return
        signal_side = "BUY"
        score_used = buy_score
        signal_details = buy_details
        
    elif sell_score >= MIN_SCORE_FOR_SIGNAL and sell_score > buy_score:
        if is_near_sr_level(current_price, support_levels, tolerance=0.015):
            print(f"[{symbol}] SELL signal por afër support, SKIP.")
            return
        signal_side = "SELL"
        score_used = sell_score
        signal_details = sell_details
    else:
        print(f"[{symbol}] ❌ No signal: BUY={buy_score}/10, SELL={sell_score}/10")
        return

    # Calculate entry, TP, SL
        return

    now_utc = datetime.now(timezone.utc)
    last_t = last_signal_time.get(symbol)
    if last_t is not None:
        minutes_since = (now_utc - last_t).total_seconds() / 60.0
        if minutes_since < MIN_MINUTES_BETWEEN_SIGNALS:
            # print(f"[{symbol}] {signal_side} ekziston {minutes_since:.1f} min mÃ« parÃ«, skip.")
            return

    prev_side = last_signal_side.get(symbol)
    if prev_side == signal_side:
        # print(f"[{symbol}] {signal_side} already sent before, skipping duplicate.")
        return

    last_signal_side[symbol] = signal_side
    last_signal_time[symbol] = now_utc

    # ===== PERCENT-BASED SL/TP =====
    if signal_side == "BUY":
        sl = current_price * (1 - SL_PERCENT)
        tp = current_price * (1 + TP_PERCENT)
    else:  # SELL
        sl = current_price * (1 + SL_PERCENT)
        tp = current_price * (1 - TP_PERCENT)
    
    # Risk/Reward check
    risk = abs(current_price - sl)
    reward = abs(tp - current_price)
    
    if risk == 0:
        return
    
    risk_reward_ratio = reward / risk
    
    if risk_reward_ratio < MIN_RISK_REWARD:
        print(f"[{symbol}] RR {risk_reward_ratio:.2f} < {MIN_RISK_REWARD}, SKIP.")
        return
    
    sl_pct = abs(sl - current_price) / current_price * 100
    tp_pct = abs(tp - current_price) / current_price * 100

    now_local = datetime.now(LOCAL_TZ).strftime("%Y-%m-%d %H:%M")

    extra = (
        f"Forex Swing 4H | D1={trend_d1}, 4H={structure_4h}, ADX={adx_value:.1f} | "
        f"Confluences: {', '.join(signal_details)} | "
        f"Score={score_used}/10, RR={risk_reward_ratio:.2f}, ATR={current_atr:.5f}, "
        f"Vol={volume_ratio:.2f}x, SL={sl_pct:.2f}%, TP={tp_pct:.2f}%"
    )

    msg = (
        f"ðŸ“Š <b>FOREX SWING SIGNAL</b>\n"
        f"Symbol: <b>{symbol.replace('=X', '')}</b>\n"
        f"Direction: <b>{signal_side}</b>\n"
        f"Price: <b>{current_price:.5f}</b>\n\n"
        f"ðŸ•’ TF: D1 + 4H\n"
        f"Trend D1: <b>{trend_d1}</b>\n"
        f"Structure 4H: <b>{structure_4h}</b>\n"
        f"ADX: <b>{adx_value:.1f}</b>\n"
        f"Volume: <b>{volume_ratio:.2f}x</b>\n"
        f"Confluence score: <b>{score_used}/7</b>\n"
        f"Risk/Reward: <b>{risk_reward_ratio:.2f}</b>\n\n"
        f"SL: <b>{sl:.5f}</b> ({sl_pct:.2f}%)\n"
        f"TP: <b>{tp:.5f}</b> ({tp_pct:.2f}%)\n\n"
        f"ðŸ“… Time: {now_local}"
    )

    print(
        f"[{symbol}] ðŸŽ¯ {signal_side} SWING @ {current_price:.5f} | "
        f"Score={score_used}/7, RR={risk_reward_ratio:.2f}, ADX={adx_value:.1f}"
    )

    # Backend
    send_signal_to_backend(
        symbol=symbol,
        direction=signal_side,
        timeframe="4H",
        entry=current_price,
        sl=sl,
        tp=tp,
        extra_text=extra,
    )

    # Log te admin
    notify_signal_sent(symbol, signal_side)

    # Telegram
    send_telegram_message(msg)


# ======================================================
#                    MAIN LOOP
# ======================================================

def main_loop():
    global last_heartbeat_ts

    start_time = datetime.now(LOCAL_TZ).strftime("%Y-%m-%d %H:%M")

    start_msg = (
        f"âœ… <b>Forex Swing scanner u startua</b>\n"
        f"ðŸ“… Time (Europe/Belgrade): <b>{start_time}</b>\n"
        f"Pairs: <b>{len(SYMBOLS)}</b> (Forex)\n"
        f"â± Scan Ã§do <b>{SLEEP_SECONDS // 60}</b> minuta."
    )
    send_telegram_message(start_msg)

    print("âœ… Forex Swing scanner started.")
    print(f"Symbols: {SYMBOLS}")
    print(f"Scan every {SLEEP_SECONDS} seconds.\n")

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
        print(f"Sleeping {SLEEP_SECONDS} seconds...\n")
        time.sleep(SLEEP_SECONDS)


if __name__ == "__main__":
    try:
        main_loop()
    except Exception:
        print("\nâŒ KISHTE NJÃ‹ GABIM NÃ‹ PROGRAM:")
        traceback.print_exc()
        input("\nShtyp ENTER qÃ« tÃ« mbyllet dritarja...")
