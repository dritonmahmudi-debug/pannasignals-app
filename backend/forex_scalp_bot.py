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

INTERVAL = "5m"         # Scalping TF
LOOKBACK_DAYS = 3       # Sa ditÃ« mbrapa pÃ«r 5m
SLEEP_SECONDS = 60      # Sa sekonda pushim mes skanimeve

# ATR multiplier pÃ«r forex scalping
ATR_MULTIPLIER_SL = 1.0  # SL = ATR * 1.0
ATR_MULTIPLIER_TP = 2.5  # TP = ATR * 2.5

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
    global last_signal_time

    df = fetch_ohlc(symbol, interval=INTERVAL, lookback_days=LOOKBACK_DAYS)
    if df.empty or len(df) < 60:
        # print(f"[{symbol}] Not enough data for scalping.")
        return

    # Llogarit indicatorÃ«t
    df["EMA20"] = compute_ema(df["Close"], period=20)
    atr = calculate_atr(df, period=14)
    df["ATR"] = atr
    
    adx_value = calculate_adx(df, period=14)
    
    # EMA Alignment (NEW - 7th factor)
    ema_alignment = check_ema_alignment(df)
    
    support_levels, resistance_levels = find_support_resistance_levels(df, lookback=150)
    bullish_div, bearish_div = detect_rsi_divergence(df, rsi_period=14, lookback=30)

    trend, h1_idx, h2_idx, l1_idx, l2_idx = classify_trend(df)

    last_close = float(df["Close"].iloc[-1])
    prev_close = float(df["Close"].iloc[-2])
    last_ema20 = float(df["EMA20"].iloc[-1])
    prev_ema20 = float(df["EMA20"].iloc[-2])
    last_atr = float(df["ATR"].iloc[-1]) if len(df["ATR"]) > 0 else 0.0
    
    # Volume check
    if len(df) >= 20:
        avg_volume = float(df["Volume"].iloc[-20:].mean())
        current_volume = float(df["Volume"].iloc[-1])
        volume_ratio = current_volume / (avg_volume + 0.00001)
        high_volume = bool(volume_ratio >= MIN_VOLUME_RATIO)
    else:
        volume_ratio = 0.0
        high_volume = False
    
    # ATR check
    if last_atr == 0.0 or last_atr < last_close * 0.0001:
        # print(f"[{symbol}] ATR shumÃ« i ulÃ«t, skip.")
        return

    # ==================================================
    #           SCORING SYSTEM (6 pika)
    # ==================================================
    
    buy_score = 0
    sell_score = 0
    buy_details = []
    sell_details = []
    
    # 1) Trend (HH/HL vs LH/LL)
    if trend == "bull":
        buy_score += 1
        buy_details.append("BULL_TREND")
    elif trend == "bear":
        sell_score += 1
        sell_details.append("BEAR_TREND")
    
    # 2) EMA20 pullback
    if trend == "bull":
        if prev_close < prev_ema20 and last_close > last_ema20:
            buy_score += 1
            buy_details.append("EMA20_BOUNCE")
    
    if trend == "bear":
        if prev_close > prev_ema20 and last_close < last_ema20:
            sell_score += 1
            sell_details.append("EMA20_REJECT")
    
    # 3) ADX trend strength
    if adx_value >= MIN_ADX_STRENGTH:
        if trend == "bull":
            buy_score += 1
            buy_details.append(f"ADX_{adx_value:.1f}")
        elif trend == "bear":
            sell_score += 1
            sell_details.append(f"ADX_{adx_value:.1f}")
    
    # 4) Volume confirmation
    if high_volume:
        if trend == "bull":
            buy_score += 1
            buy_details.append(f"VOL_{volume_ratio:.2f}x")
        if trend == "bear":
            sell_score += 1
            sell_details.append(f"VOL_{volume_ratio:.2f}x")
    
    # 5) RSI Divergence
    if bullish_div:
        buy_score += 1
        buy_details.append("RSI_BULL_DIV")
    if bearish_div:
        sell_score += 1
        sell_details.append("RSI_BEAR_DIV")
    
    # 6) Jo afër S/R
    near_resistance = is_near_sr_level(last_close, resistance_levels, tolerance=0.008)
    near_support = is_near_sr_level(last_close, support_levels, tolerance=0.008)
    
    if not near_resistance and trend == "bull":
        buy_score += 0.5
    if not near_support and trend == "bear":
        sell_score += 0.5
    
    # 7) EMA Alignment
    if ema_alignment == "bull":
        buy_score += 1
        buy_details.append("EMA_ALIGNED")
    elif ema_alignment == "bear":
        sell_score += 1
        sell_details.append("EMA_ALIGNED")
    
    # 8) MACD Crossover
    macd_line, signal_line, histogram, macd_bull_cross, macd_bear_cross = calculate_macd(df)
    if macd_bull_cross:
        buy_score += 1
        buy_details.append("MACD_CROSS")
    if macd_bear_cross:
        sell_score += 1
        sell_details.append("MACD_CROSS")
    
    # 9) Stochastic
    k_val, d_val, stoch_oversold_cross, stoch_overbought_cross = calculate_stochastic(df)
    if stoch_oversold_cross:
        buy_score += 1
        buy_details.append("STOCH_OVER")
    if stoch_overbought_cross:
        sell_score += 1
        sell_details.append("STOCH_OVER")
    
    # ==================================================
    #                   DECISION
    # ==================================================
    
    side = None
    score_used = 0
    signal_details = []
    
    if buy_score >= MIN_SCORE_FOR_SIGNAL and buy_score >= sell_score:
        if near_resistance:
            print(f"[{symbol}] BUY signal por afër resistance, SKIP.")
            return
        side = "BUY"
        score_used = buy_score
        signal_details = buy_details
        
    elif sell_score >= MIN_SCORE_FOR_SIGNAL and sell_score > buy_score:
        if near_support:
            print(f"[{symbol}] SELL signal por afër support, SKIP.")
            return
        side = "SELL"
        score_used = sell_score
        signal_details = sell_details
    else:
        print(f"[{symbol}] ❌ No signal: BUY={buy_score:.1f}/9, SELL={sell_score:.1f}/9")
        return

    # Kontrol frekuencë
    key = (symbol, side)
    now = datetime.now(timezone.utc)
    last_t = last_signal_time.get(key)
    if last_t is not None:
        minutes_since = (now - last_t).total_seconds() / 60.0
        if minutes_since < MIN_MINUTES_BETWEEN_SIGNALS:
            # print(f"[{symbol}] {side} setup, por ka {minutes_since:.1f} min nga sinjali i fundit -> SKIP.")
            return

    last_signal_time[key] = now

    # ===== ATR-BASED DYNAMIC SL/TP =====
    atr_sl_distance = last_atr * ATR_MULTIPLIER_SL
    atr_tp_distance = last_atr * ATR_MULTIPLIER_TP
    
    if side == "BUY":
        sl = last_close - atr_sl_distance
        tp = last_close + atr_tp_distance
    else:  # SELL
        sl = last_close + atr_sl_distance
        tp = last_close - atr_tp_distance
    
    # Risk/Reward check
    risk = abs(last_close - sl)
    reward = abs(tp - last_close)
    
    if risk == 0:
        return
    
    risk_reward_ratio = reward / risk
    
    if risk_reward_ratio < MIN_RISK_REWARD:
        print(f"[{symbol}] RR {risk_reward_ratio:.2f} < {MIN_RISK_REWARD}, SKIP.")
        return
    
    sl_pct = abs(sl - last_close) / last_close * 100
    tp_pct = abs(tp - last_close) / last_close * 100

    extra_text = (
        f"Forex Scalp 5m | Trend={trend}, ADX={adx_value:.1f} | "
        f"Confluences: {', '.join(signal_details)} | "
        f"Score={score_used:.1f}/9, RR={risk_reward_ratio:.2f}, ATR={last_atr:.5f}, "
        f"Vol={volume_ratio:.2f}x, SL={sl_pct:.2f}%, TP={tp_pct:.2f}%"
    )

    print(
        f"[{symbol}] ðŸŽ¯ {side} SCALP @ {last_close:.5f} (SL={sl:.5f}, TP={tp:.5f}) | "
        f"Score={score_used:.1f}/9, RR={risk_reward_ratio:.2f}, ADX={adx_value:.1f}"
    )

    # 1) DÃ«rgo sinjalin te tabela kryesore
    send_signal_to_backend(
        symbol=symbol,
        direction=side,
        timeframe=INTERVAL,
        entry=last_close,
        sl=sl,
        tp=tp,
        extra_text=extra_text,
    )

    # 2) Njofto admin backend-in
    notify_signal_sent(symbol, side)


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
        print(f"Sleeping {SLEEP_SECONDS} seconds...\n")
        time.sleep(SLEEP_SECONDS)


if __name__ == "__main__":
    try:
        main_loop()
    except Exception:
        print("\nâŒ KISHTE NJÃ‹ GABIM NÃ‹ PROGRAM:")
        traceback.print_exc()
        input("\nShtyp ENTER qÃ« tÃ« mbyllet dritarja...")
