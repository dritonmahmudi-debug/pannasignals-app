def calculate_ma(df, period=50):
    return df['close'].rolling(window=period).mean().iloc[-1]
import time
from datetime import datetime, timedelta, timezone
from typing import Dict, Tuple, Optional, List

import numpy as np
import pandas as pd
import requests
import traceback

# ======================================================
#                     CONFIG
# ======================================================

# Backend FastAPI (lokal) â€“ PERDOR PORTIN 8000
BACKEND_URL = "http://127.0.0.1:8000/signals"   # tabela kryesore e sinjaleve
ADMIN_API_BASE = "http://127.0.0.1:8000"        # pÃ«r /admin/bot_... endpoint-et

# Identifikimi i kÃ«tij boti
BOT_ID = "crypto_swing_bot"

# KÃ«to pÃ«rdoren nÃ« app
SOURCE_NAME = "crypto_swing_bot"
ANALYSIS_TYPE = "crypto_swing"   # lidhet me filtrin Crypto Swing nÃ« app

BINANCE_FAPI_BASE = "https://fapi.binance.com"

# Sa koinÃ« duam (top 100 USDT-M perpetual)
TOP_N_SYMBOLS = 100

# Timeframes
INTERVAL_D1 = "1d"
INTERVAL_4H = "4h"

# Sa candles marrim
LIMIT_D1 = 260      # mjafton pÃ«r EMA200
LIMIT_4H = 300

# Sa sekonda pushim mes skanimeve
SLEEP_SECONDS = 600   # 10 minuta

# Risk pÃ«r swing
SL_PCT = 0.015      # 1.5%
TP_PCT = 0.045      # 4.5%

# Min. distancÃ« mes sinjaleve pÃ«r tÃ« njÃ«jtin simbol/direction (nÃ« minuta)
MIN_MINUTES_BETWEEN_SIGNALS = 120

# Sa pikÃ« konfluence kÃ«rkojmÃ« (nga 8)
MIN_SCORE_FOR_SIGNAL = 6

# FIXED percentage pÃ«r SL/TP (nÃ« vend tÃ« ATR-based)
FIXED_SL_PERCENT = 1.5  # 1.5% stop loss
FIXED_TP_PERCENT = 4.5  # 4.5% take profit

# Minimum Risk/Reward ratio (automatikisht 4.5/1.5 = 3.0)
MIN_RISK_REWARD = 2.0  # TP duhet tÃ« jetÃ« minimum 2x SL

# ADX threshold pÃ«r trend strength
MIN_ADX_STRENGTH = 20  # ulur nga 25 -> 20 pÃ«r mÃ« shumÃ« sinjale

# Volume confirmation threshold
MIN_VOLUME_RATIO = 1.2  # volume aktual duhet tÃ« jetÃ« 1.2x mbi mesatare

# Memorie pÃ«r sinjalin e fundit
last_signal_side: Dict[str, str] = {}
last_signal_time: Dict[Tuple[str, str], datetime] = {}  # (symbol, side) -> time

# Heartbeat config
HEARTBEAT_INTERVAL = 300  # 5 minuta
last_heartbeat_ts: float = 0.0


# ======================================================
#                  BINANCE HELPERS
# ======================================================

def get_top_usdt_perps(limit: int = TOP_N_SYMBOLS) -> List[str]:
    """
    Merr listÃ«n e top USDT-M PERPETUAL futures simboleve sipas volume 24h.
    """
    try:
        # 1) Gjej tÃ« gjitha USDT-M PERPETUAL qÃ« janÃ« TRADING
        ex_info = requests.get(
            f"{BINANCE_FAPI_BASE}/fapi/v1/exchangeInfo", timeout=10
        ).json()
        all_symbols = [
            s["symbol"]
            for s in ex_info["symbols"]
            if s.get("contractType") == "PERPETUAL"
            and s.get("quoteAsset") == "USDT"
            and s.get("status") == "TRADING"
        ]

        # 2) Merr ticker 24h dhe sorto sipas qarkullimit (quoteVolume)
        tickers = requests.get(
            f"{BINANCE_FAPI_BASE}/fapi/v1/ticker/24hr", timeout=10
        ).json()
        vol_map = {t["symbol"]: float(t.get("quoteVolume", 0.0)) for t in tickers}

        filtered = [s for s in all_symbols if s in vol_map]
        filtered.sort(key=lambda sym: vol_map.get(sym, 0.0), reverse=True)

        top = filtered[:limit]
        print(f"[SYMBOLS] USDT-M PERPETUAL: {len(top)} simbole (TOP {limit}).")
        return top

    except Exception:
        print("[SYMBOLS] Exception duke marrÃ« listÃ«n e simboleve nga Binance:")
        traceback.print_exc()
        # fallback disa simbole kryesore
        return [
            "BTCUSDT", "ETHUSDT", "BNBUSDT", "SOLUSDT", "XRPUSDT",
            "ADAUSDT", "AVAXUSDT", "LINKUSDT", "DOGEUSDT", "DOTUSDT"
        ]


def fetch_klines(symbol: str, interval: str, limit: int) -> pd.DataFrame:
    """
    Merr OHLCV nga Binance Futures USDT-M.
    """
    try:
        url = f"{BINANCE_FAPI_BASE}/fapi/v1/klines"
        params = {"symbol": symbol, "interval": interval, "limit": limit}
        resp = requests.get(url, params=params, timeout=10)
        if not resp.ok:
            print(f"[{symbol}] Klines error {resp.status_code}: {resp.text}")
            return pd.DataFrame()

        data = resp.json()
        if not data:
            print(f"[{symbol}] No klines data interval={interval}")
            return pd.DataFrame()

        # Klines format: [ openTime, open, high, low, close, volume, closeTime, ... ]
        rows = []
        for k in data:
            rows.append(
                (
                    int(k[0]),
                    float(k[1]),
                    float(k[2]),
                    float(k[3]),
                    float(k[4]),
                    float(k[5]),
                )
            )
        df = pd.DataFrame(
            rows, columns=["open_time", "Open", "High", "Low", "Close", "Volume"]
        )
        df["open_time"] = pd.to_datetime(df["open_time"], unit="ms", utc=True)
        df.set_index("open_time", inplace=True)
        df = df.sort_index()
        return df

    except Exception:
        print(f"[{symbol}] Exception in fetch_klines({interval}):")
        traceback.print_exc()
        return pd.DataFrame()


# ======================================================
#                  ATR (Average True Range)
# ======================================================

# ======================================================
#                  RSI (Relative Strength Index)
# ======================================================

def calculate_rsi(df: pd.DataFrame, period: int = 14) -> float:
    """
    Llogarit RSI për df['Close'].
    Kthen: RSI vlera e fundit (0-100).
    """
    close = df['Close']
    delta = close.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    rs = gain / (loss + 1e-9)
    rsi = 100 - (100 / (1 + rs))
    return float(rsi.iloc[-1]) if len(rsi) > 0 else 0.0

def calculate_atr(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """
    Llogarit ATR (Average True Range) pÃ«r volatility measurement.
    """
    high = df['High']
    low = df['Low']
    close = df['Close']
    
    # True Range = max(high-low, abs(high-prev_close), abs(low-prev_close))
    tr1 = high - low
    tr2 = abs(high - close.shift())
    tr3 = abs(low - close.shift())
    
    tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
    atr = tr.ewm(span=period, adjust=False).mean()
    
    return atr


# ======================================================
#                  ADX (Trend Strength)
# ======================================================

def calculate_adx(df: pd.DataFrame, period: int = 14) -> float:
    """
    Llogarit ADX (Average Directional Index) pÃ«r tÃ« matur forcÃ«n e trendit.
    Kthim: ADX value (0-100). Mbi 25 = trend i fortÃ«.
    """
    high = df['High'].values
    low = df['Low'].values
    close = df['Close'].values
    
    if len(df) < period + 1:
        return 0.0
    
    # +DM dhe -DM
    plus_dm = np.zeros(len(df))
    minus_dm = np.zeros(len(df))
    
    for i in range(1, len(df)):
        high_diff = high[i] - high[i-1]
        low_diff = low[i-1] - low[i]
        
        if high_diff > low_diff and high_diff > 0:
            plus_dm[i] = high_diff
        if low_diff > high_diff and low_diff > 0:
            minus_dm[i] = low_diff
    
    # ATR
    atr = calculate_atr(df, period).values
    
    # +DI dhe -DI
    plus_di = 100 * pd.Series(plus_dm).ewm(span=period, adjust=False).mean() / atr
    minus_di = 100 * pd.Series(minus_dm).ewm(span=period, adjust=False).mean() / atr
    
    # DX
    dx = 100 * abs(plus_di - minus_di) / (plus_di + minus_di + 0.00001)
    
    # ADX
    adx = dx.ewm(span=period, adjust=False).mean()
    
    return float(adx.iloc[-1]) if len(adx) > 0 else 0.0


def check_ema_alignment(df: pd.DataFrame) -> str:
    """
    Kontrollon alignment të EMA 8, 21, 50 për trend confirmation.
    Returns: "bull", "bear", or "neutral"
    """
    if len(df) < 50:
        return "neutral"
    
    ema8 = df['Close'].ewm(span=8, adjust=False).mean().iloc[-1]
    ema21 = df['Close'].ewm(span=21, adjust=False).mean().iloc[-1]
    ema50 = df['Close'].ewm(span=50, adjust=False).mean().iloc[-1]
    
    # Bullish alignment: EMA8 > EMA21 > EMA50
    if ema8 > ema21 > ema50:
        return "bull"
    # Bearish alignment: EMA8 < EMA21 < EMA50
    elif ema8 < ema21 < ema50:
        return "bear"
    else:
        return "neutral"


# ======================================================
#                D1 TREND (EMA50 / EMA200)
# ======================================================

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
#           SWINGS HH / HL / LH / LL NÃ‹ 4H
# ======================================================

def find_swings(df: pd.DataFrame, lookback: int = 3):
    """
    Gjen indekset e swing high & swing low.
    Kthen dy numpy array (int).
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

    return np.array(swing_high_idx, dtype=int), np.array(swing_low_idx, dtype=int)


def classify_structure(h4: pd.DataFrame):
    """
    Klasifikon strukturÃ«n 4H si "bull", "bear", ose "choppy".
    Kthen:
      structure, swing_high_idx, swing_low_idx
    """
    if h4.empty or len(h4) < 40:
        return "choppy", np.array([], dtype=int), np.array([], dtype=int)

    swing_high_idx, swing_low_idx = find_swings(h4, lookback=2)
    if len(swing_high_idx) < 2 or len(swing_low_idx) < 2:
        return "choppy", swing_high_idx, swing_low_idx

    # dy high & dy low tÃ« fundit
    last_two_highs = swing_high_idx[-2:]
    last_two_lows = swing_low_idx[-2:]

    h1_idx = int(last_two_highs[0])
    h2_idx = int(last_two_highs[1])
    l1_idx = int(last_two_lows[0])
    l2_idx = int(last_two_lows[1])

    h1 = float(h4["High"].iloc[h1_idx])
    h2 = float(h4["High"].iloc[h2_idx])
    l1 = float(h4["Low"].iloc[l1_idx])
    l2 = float(h4["Low"].iloc[l2_idx])

    # Bullish: HH & HL
    if h2 > h1 and l2 >= l1:
        return "bull", swing_high_idx, swing_low_idx

    # Bearish: LH & LL
    if h2 <= h1 and l2 < l1:
        return "bear", swing_high_idx, swing_low_idx

    return "choppy", swing_high_idx, swing_low_idx


# ======================================================
#                  ORDER BLOCK (4H)
# ======================================================

def find_recent_order_block(df: pd.DataFrame, direction: str, lookback: int = 60) -> Optional[Tuple[float, float, float]]:
    """
    Gjen njÃ« order block tÃ« fundit me kritere tÃ« pÃ«rmirÃ«suara.
    Kthen (low, high, strength) tÃ« OB.
    strength = 0-100 (sa i fortÃ« Ã«shtÃ« OB)
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
            # Duhet tÃ« jetÃ« qiri bullish i fortÃ«
            if candle_close <= candle_open:
                continue
            
            body_ratio = candle_body / (candle_high - candle_low + 0.00001)
            if body_ratio < 0.6:  # qiri duhet tÃ« ketÃ« body tÃ« fortÃ«
                continue

            # Downmove para tij
            prev_close = closes[i - 1]
            prev2_close = closes[i - 2]
            if not (prev_close < prev2_close):
                continue

            # Volume duhet tÃ« jetÃ« mbi mesatare
            volume_ratio = candle_volume / (avg_volume + 0.00001)
            if volume_ratio < 1.1:
                continue

            # Rikthim i Ã§mimit nÃ« zonÃ«n e OB
            next_low = sub["Low"].iloc[i + 1:i + 4].min() if i + 4 < len(sub) else sub["Low"].iloc[i + 1:].min()
            if next_low <= candle_low * 1.002:
                # Llogarit strength
                strength = min(100, volume_ratio * 30 + body_ratio * 40 + 30)
                
                if strength > best_strength:
                    best_strength = strength
                    best_ob = (float(candle_low), float(candle_high), float(strength))

        elif direction == "bear":
            # Duhet tÃ« jetÃ« qiri bearish i fortÃ«
            if candle_close >= candle_open:
                continue
            
            body_ratio = candle_body / (candle_high - candle_low + 0.00001)
            if body_ratio < 0.6:
                continue

            # Upmove para tij
            prev_close = closes[i - 1]
            prev2_close = closes[i - 2]
            if not (prev_close > prev2_close):
                continue

            # Volume mbi mesatare
            volume_ratio = candle_volume / (avg_volume + 0.00001)
            if volume_ratio < 1.1:
                continue

            # Rikthim nÃ« zonÃ«
            next_high = sub["High"].iloc[i + 1:i + 4].max() if i + 4 < len(sub) else sub["High"].iloc[i + 1:].max()
            if next_high >= candle_high * 0.998:
                strength = min(100, volume_ratio * 30 + body_ratio * 40 + 30)
                
                if strength > best_strength:
                    best_strength = strength
                    best_ob = (float(candle_low), float(candle_high), float(strength))

    return best_ob


# ======================================================
#                  VOLUME CONFIRMATION
# ======================================================

def check_volume_confirmation(df: pd.DataFrame, lookback: int = 20) -> Tuple[bool, float]:
    """
    Kontrollon nÃ«se volume aktual Ã«shtÃ« mÃ« i lartÃ« se mesatarja.
    Kthim: (is_high_volume, volume_ratio)
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


# ======================================================
#              SUPPORT / RESISTANCE LEVELS
# ======================================================

def find_support_resistance_levels(df: pd.DataFrame, lookback: int = 100, num_levels: int = 5) -> Tuple[List[float], List[float]]:
    """
    Gjen nivelet kryesore tÃ« support dhe resistance duke pÃ«rdorur swing highs/lows.
    Kthim: (support_levels, resistance_levels)
    """
    if df.empty or len(df) < lookback:
        return [], []
    
    recent_df = df.iloc[-lookback:]
    highs = recent_df['High'].values
    lows = recent_df['Low'].values
    
    # Gjen local highs dhe lows
    resistance_levels = []
    support_levels = []
    
    for i in range(5, len(recent_df) - 5):
        # Resistance: local high
        if highs[i] == max(highs[i-5:i+6]):
            resistance_levels.append(highs[i])
        
        # Support: local low
        if lows[i] == min(lows[i-5:i+6]):
            support_levels.append(lows[i])
    
    # Cluster similar levels (brenda 0.5%)
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


def is_near_sr_level(price: float, levels: List[float], tolerance: float = 0.01) -> bool:
    """
    Kontrollon nÃ«se Ã§mimi Ã«shtÃ« afÃ«r njÃ« niveli S/R (brenda tolerance %).
    """
    for level in levels:
        if abs(price - level) / level <= tolerance:
            return True
    return False


# ======================================================
#                  RSI DIVERGENCE
# ======================================================

def detect_rsi_divergence(df: pd.DataFrame, rsi_period: int = 14, lookback: int = 30) -> Tuple[bool, bool]:
    """
    Detekton bullish dhe bearish divergence nÃ« RSI.
    Kthim: (bullish_div, bearish_div)
    """
    if df.empty or len(df) < rsi_period + lookback:
        return False, False
    
    # Llogarit RSI
    close = df['Close']
    delta = close.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=rsi_period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=rsi_period).mean()
    rs = gain / (loss + 0.00001)
    rsi = 100 - (100 / (1 + rs))
    
    recent_df = df.iloc[-lookback:].copy()
    recent_rsi = rsi.iloc[-lookback:].values
    recent_price = recent_df['Close'].values
    
    # Gjen swing lows dhe highs
    bullish_div = False
    bearish_div = False
    
    for i in range(5, len(recent_df) - 5):
        # Bullish divergence: Ã§mimi bÃ«n LL por RSI bÃ«n HL
        if i > 10:
            # Gjen dy lows
            if recent_price[i] < recent_price[i-10]:
                if recent_rsi[i] > recent_rsi[i-10]:
                    bullish_div = True
        
        # Bearish divergence: Ã§mimi bÃ«n HH por RSI bÃ«n LH
        if i > 10:
            if recent_price[i] > recent_price[i-10]:
                if recent_rsi[i] < recent_rsi[i-10]:
                    bearish_div = True
    
    return bullish_div, bearish_div


# ======================================================
#                     FVG (4H)
# ======================================================

def has_recent_fvg(df: pd.DataFrame, direction: str, lookback: int = 40) -> bool:
    """
    FVG i thjeshtuar (3 qirinj).
    direction: "bull" -> void poshtÃ« cmimit
               "bear" -> void sipÃ«r cmimit
    """
    if df.empty or len(df) < 10:
        return False

    sub = df.iloc[-(lookback + 2):]
    highs = sub["High"].values
    lows = sub["Low"].values

    for i in range(1, len(sub) - 1):
        # qiri qendror = i
        if direction == "bull":
            # low i qirit qendror mbi high tÃ« qirit tÃ« majtÃ«
            if lows[i] > highs[i - 1]:
                return True
        elif direction == "bear":
            # high i qirit qendror poshtÃ« low tÃ« qirit tÃ« majtÃ«
            if highs[i] < lows[i - 1]:
                return True

    return False


# ======================================================
#                   CRT (Change of Character)
# ======================================================

def detect_crt(h4: pd.DataFrame,
               swing_high_idx: np.ndarray,
               swing_low_idx: np.ndarray,
               direction: str) -> bool:
    """
    CRT (shumÃ« thjesht):
      - pÃ«r BUY: Ã§mimi mbyllet mbi swing high tÃ« fundit -> bull CRT
      - pÃ«r SELL: Ã§mimi mbyllet poshtÃ« swing low tÃ« fundit -> bear CRT
    """
    if h4.empty:
        return False
    if direction == "bull":
        if len(swing_high_idx) < 1:
            return False
        last_high_i = int(swing_high_idx[-1])
        last_high = float(h4["High"].iloc[last_high_i])
        last_close = float(h4["Close"].iloc[-1])
        return last_close > last_high
    elif direction == "bear":
        if len(swing_low_idx) < 1:
            return False
        last_low_i = int(swing_low_idx[-1])
        last_low = float(h4["Low"].iloc[last_low_i])
        last_close = float(h4["Close"].iloc[-1])
        return last_close < last_low

    return False


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
#                 BACKEND â€“ SEND SIGNAL
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
#                    SIGNAL LOGIC
# ======================================================

def analyze_symbol(symbol: str):
    global last_signal_side, last_signal_time

    # ---------- D1 ----------
    d1 = fetch_klines(symbol, INTERVAL_D1, LIMIT_D1)
    if d1.empty:
        print(f"[{symbol}] No D1 data.")
        return
    trend_d1 = detect_trend_d1(d1)

    # ---------- 4H ----------
    h4 = fetch_klines(symbol, INTERVAL_4H, LIMIT_4H)
    if h4.empty or len(h4) < 60:
        print(f"[{symbol}] No/low 4H data.")
        return

    structure_4h, swing_high_idx, swing_low_idx = classify_structure(h4)
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

    crt_bull = detect_crt(h4, swing_high_idx, swing_low_idx, "bull")
    crt_bear = detect_crt(h4, swing_high_idx, swing_low_idx, "bear")

    # 12) MA50 Trend (FAKTOR I RI)
    ma50 = calculate_ma(h4, period=50)
    if current_price > ma50:
        buy_score += 1
        buy_details.append(f"MA50_BULL")
    elif current_price < ma50:
        sell_score += 1
        sell_details.append(f"MA50_BEAR")

    # ==================================================
    #           SCORE BUY / SELL (8 pika tani!)
    # ==================================================

    buy_score = 0
    sell_score = 0
    buy_details = []
    sell_details = []

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
        buy_details.append("4H_BULL_STRUCT")
    elif structure_4h == "bear":
        sell_score += 1
        sell_details.append("4H_BEAR_STRUCT")

    # 3) ADX - trend strength (CRITICAL)
    if adx_value >= MIN_ADX_STRENGTH:
        if trend_d1 == "bull":
            buy_score += 1
            buy_details.append(f"ADX_{adx_value:.1f}")
        elif trend_d1 == "bear":
            sell_score += 1
            sell_details.append(f"ADX_{adx_value:.1f}")
    else:
        # Weak trend - penalizojm
        print(f"[{symbol}] ADX={adx_value:.1f} < {MIN_ADX_STRENGTH} (weak trend), reducing reliability")

    # 4) Volume confirmation
    if high_volume:
        if trend_d1 == "bull" or structure_4h == "bull":
            buy_score += 1
            buy_details.append(f"VOL_{volume_ratio:.2f}x")
        if trend_d1 == "bear" or structure_4h == "bear":
            sell_score += 1
            sell_details.append(f"VOL_{volume_ratio:.2f}x")

    # 5) Order Block afÃ«r Ã§mimit (me strength)
    if bull_ob is not None:
        ob_low, ob_high, ob_strength = bull_ob
        if ob_low <= current_price <= ob_high * 1.01:
            buy_score += 1
            buy_details.append(f"OB_BULL_{ob_strength:.0f}%")
    if bear_ob is not None:
        ob_low, ob_high, ob_strength = bear_ob
        if ob_low * 0.99 <= current_price <= ob_high:
            sell_score += 1
            sell_details.append(f"OB_BEAR_{ob_strength:.0f}%")

    # 6) FVG
    if bull_fvg:
        buy_score += 1
        buy_details.append("FVG_BULL")
    if bear_fvg:
        sell_score += 1
        sell_details.append("FVG_BEAR")
    
    # 7) RSI Divergence (shumÃ« e fortÃ« pÃ«r reversal)
    if bullish_div:
        buy_score += 1
        buy_details.append("RSI_DIV")
    if bearish_div:
        sell_score += 1
        sell_details.append("RSI_DIV")
    
    # 8) EMA Alignment (zëvendëson CRT)
    if ema_alignment == "bull":
        buy_score += 1
        buy_details.append("EMA_ALIGNED")
    elif ema_alignment == "bear":
        sell_score += 1
        sell_details.append("EMA_ALIGNED")

    # 9) RSI absolute value (NEW)
    rsi_value = calculate_rsi(h4, period=14)
    if rsi_value < 32:
        buy_score += 1
        buy_details.append(f"RSI_{rsi_value:.1f}")
    if rsi_value > 68:
        sell_score += 1
        sell_details.append(f"RSI_{rsi_value:.1f}")
    # 10) Stochastic Oscillator
    k, d = calculate_stochastic(h4, k_period=14, d_period=3)
    if k < 20 and k > d:
        buy_score += 1
        buy_details.append(f"STOCH_K={k:.1f}")
    if k > 80 and k < d:
        sell_score += 1
        sell_details.append(f"STOCH_K={k:.1f}")
    # 11) Candle Pattern Detection
    bullish_candle, bearish_candle = detect_candle_pattern(h4)
    if bullish_candle:
        buy_score += 1
        buy_details.append("CANDLE_BULLISH")
    if bearish_candle:
        sell_score += 1
        sell_details.append("CANDLE_BEARISH")

    # ==================================================
    #              DECISION LOGIC
    # ==================================================
    
    # Kontrollo ATR validityn
    if current_atr == 0.0 or current_atr < current_price * 0.001:
        print(f"[{symbol}] ATR shumÃ« i ulÃ«t ose 0, skip signal.")
        return
    
    # Vendimi
    signal_side = None
    score_used = 0
    signal_details = []

    if buy_score >= MIN_SCORE_FOR_SIGNAL and buy_score >= sell_score:
        # Kontrollo nÃ«se jemi afÃ«r resistance
        if is_near_sr_level(current_price, resistance_levels, tolerance=0.015):
            print(f"[{symbol}] BUY signal por Ã§mimi afÃ«r resistance level, SKIP.")
            return
        
        signal_side = "BUY"
        score_used = buy_score
        signal_details = buy_details
        
    elif sell_score >= MIN_SCORE_FOR_SIGNAL and sell_score > buy_score:
        # Kontrollo nÃ«se jemi afÃ«r support
        if is_near_sr_level(current_price, support_levels, tolerance=0.015):
            print(f"[{symbol}] SELL signal por Ã§mimi afÃ«r support level, SKIP.")
            return
        
        signal_side = "SELL"
        score_used = sell_score
        signal_details = sell_details

    if signal_side is None:
        # print(f"[{symbol}] No strong swing signal. (buy={buy_score}, sell={sell_score})")
        return

    # Mos dÃ«rgo sinjal tÃ« njÃ«jtÃ« disa herÃ« rresht
    prev_side = last_signal_side.get(symbol)
    if prev_side == signal_side:
        print(f"[{symbol}] {signal_side} already sent before, skipping duplicate.")
        return

    # Kontrollo distancÃ«n nÃ« kohÃ«
    now = datetime.now(timezone.utc)
    key = (symbol, signal_side)
    last_t = last_signal_time.get(key)
    if last_t is not None:
        minutes_since = (now - last_t).total_seconds() / 60.0
        if minutes_since < MIN_MINUTES_BETWEEN_SIGNALS:
            print(
                f"[{symbol}] {signal_side} setup (score={score_used}) por ka vetÃ«m "
                f"{minutes_since:.1f} min nga sinjali i fundit -> SKIP."
            )
            return

    last_signal_side[symbol] = signal_side
    last_signal_time[key] = now

    # ===== FIXED PERCENTAGE SL/TP (1.5% SL, 4.5% TP) =====
    sl_distance_pct = FIXED_SL_PERCENT / 100.0  # 0.015
    tp_distance_pct = FIXED_TP_PERCENT / 100.0  # 0.045
    
    if signal_side == "BUY":
        sl = current_price * (1 - sl_distance_pct)
        tp = current_price * (1 + tp_distance_pct)
    else:  # SELL
        sl = current_price * (1 + sl_distance_pct)
        tp = current_price * (1 - tp_distance_pct)
    
    # Risk/Reward Ã«shtÃ« automatikisht 4.5/1.5 = 3.0
    risk_reward_ratio = FIXED_TP_PERCENT / FIXED_SL_PERCENT
    
    # Llogarit pÃ«rqindje pÃ«r display
    sl_pct = FIXED_SL_PERCENT
    tp_pct = FIXED_TP_PERCENT

    extra_text = (
        f"Crypto Swing 4H | D1={trend_d1}, 4H={structure_4h}, ADX={adx_value:.1f} | "
        f"Confluences: {', '.join(signal_details)} | "
        f"Score={score_used}/8, RR={risk_reward_ratio:.2f}, ATR={current_atr:.4f}, "
        f"Vol={volume_ratio:.2f}x, SL={sl_pct:.2f}%, TP={tp_pct:.2f}%"
    )

    print(
        f"[{symbol}] ðŸŽ¯ NEW {signal_side} SWING SIGNAL -> price={current_price:.4f} "
        f"SL={sl:.4f} TP={tp:.4f} | Score={score_used}/8, RR={risk_reward_ratio:.2f}, "
        f"ADX={adx_value:.1f}, Vol={volume_ratio:.2f}x"
    )

    # 1) DÃ«rgo sinjalin te tabela kryesore
    send_signal_to_backend(
        symbol=symbol,
        direction=signal_side,
        timeframe="4H",
        entry=current_price,
        sl=sl,
        tp=tp,
        extra_text=extra_text,
    )

    # 2) Njofto admin backend-in qÃ« u dÃ«rgua sinjal
    notify_signal_sent(symbol, signal_side)


# ======================================================
#                    MAIN LOOP
# ======================================================

def main_loop():
    global last_heartbeat_ts

    symbols = get_top_usdt_perps(TOP_N_SYMBOLS)
    print("ðŸš€ Crypto SWING bot started.")
    print(f"Source: {SOURCE_NAME}")
    print(f"Analysis type: {ANALYSIS_TYPE}")
    print(f"Symbols: {len(symbols)}  (top {TOP_N_SYMBOLS} USDT-M PERPETUAL)")
    print(f"TF: D1 + 4H, scan every {SLEEP_SECONDS} seconds.\n")

    # dÃ«rgo njÃ« heartbeat kur starton
    send_heartbeat()
    last_heartbeat_ts = time.time()

    while True:
        now_ts = time.time()

        # heartbeat periodik
        if now_ts - last_heartbeat_ts > HEARTBEAT_INTERVAL:
            send_heartbeat()
            last_heartbeat_ts = now_ts

        for symbol in symbols:
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
