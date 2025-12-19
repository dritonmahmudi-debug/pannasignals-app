import time
from datetime import datetime, timezone
from zoneinfo import ZoneInfo
import traceback

import requests
import pandas as pd
import numpy as np

# =====================================================
#                     CONFIG
# =====================================================

# Backend FastAPI ΓÇô SIGUROHU QE PORTI ESHTE I NJEJTI ME UVICORN
BACKEND_URL = "http://127.0.0.1:8000/signals"      # p├½r ruajtjen e sinjaleve
ADMIN_API_BASE = "http://127.0.0.1:8000"           # p├½r /admin/bot_... endpoint-et

# Identifikimi i k├½tij boti
BOT_ID = "crypto_scalper_bot"

# K├½to p├½rdoren n├½ app
SOURCE_NAME = "crypto_scalper_bot"
ANALYSIS_TYPE = "crypto_scalping"  # duhet t├½ jet├½ i nj├½jt├½ me app-in

# Binance Futures USDT-M
BINANCE_FAPI_URL = "https://fapi.binance.com"

LOCAL_TZ = ZoneInfo("Europe/Belgrade")

# Sa sekonda mes skanimeve
SCAN_INTERVAL = 600  # 4 minuta (më pak skanime)

# Sa minuta minimalisht mes sinjaleve për të njëjtin simbol
MIN_MINUTES_BETWEEN_SIGNALS = 60  # 1 orë (më pak spam)

# Limitimi i sinjaleve: kërkojmë 5 nga 6 kushte të forta
MIN_SCORE_FOR_SIGNAL = 6  # më strikt (ishte 4)

# FIXED percentage për SL/TP (në vend të ATR-based)
FIXED_SL_PERCENT = 1.5  # 1.5% stop loss
FIXED_TP_PERCENT = 4.5  # 4.5% take profit

# Minimum Risk/Reward ratio (nuk nevojitet sepse e kemi fixed 1.5/4.5 = 3.0)
MIN_RISK_REWARD = 2.5  # më i lartë për cilësi më të mirë (ishte 2.2)

# ADX threshold për trend strength
MIN_ADX_STRENGTH = 20  # ulur për më shumë sinjale (ishte 28)

# Volume confirmation threshold
MIN_VOLUME_RATIO = 1.8  # volume duhet të jetë 1.8x mbi mesatare (ishte 1.5)

# Memorie p├½r sinjalin e fundit
last_signal_time = {}   # { "BTCUSDT": datetime }
last_signal_side = {}   # { "BTCUSDT": "BUY" ose "SELL" }

# Heartbeat config
HEARTBEAT_INTERVAL = 300  # 5 minuta
last_heartbeat_ts = 0.0   # timestamp (time.time())


# =====================================================
#              HELPER: FUTURES SYMBOLS
# =====================================================

def fetch_usdt_perpetual_symbols():
    """
    Merr t├½ gjitha simbolet USDT-M PERPETUAL nga Binance Futures.
    P.sh. BTCUSDT, ETHUSDT, SOLUSDT, etj.
    """
    try:
        resp = requests.get(f"{BINANCE_FAPI_URL}/fapi/v1/exchangeInfo", timeout=10)
        resp.raise_for_status()
        data = resp.json()
        symbols = []
        for s in data.get("symbols", []):
            if (
                s.get("contractType") == "PERPETUAL"
                and s.get("quoteAsset") == "USDT"
                and s.get("status") == "TRADING"
            ):
                symbols.append(s["symbol"])
        print(f"[SYMBOLS] USDT-M PERPETUAL: {len(symbols)} simbole.")
        return symbols
    except Exception as e:
        print(f"[SYMBOLS] ERROR duke marr├½ simbolet: {e}")
        traceback.print_exc()
        return []


# =====================================================
#              HELPER: KLINES / OHLC
# =====================================================

def fetch_klines(symbol: str, interval: str, limit: int = 500) -> pd.DataFrame:
    """
    Merr klines nga Binance Futures si DataFrame.
    """
    try:
        params = {
            "symbol": symbol,
            "interval": interval,
            "limit": limit,
        }
        resp = requests.get(f"{BINANCE_FAPI_URL}/fapi/v1/klines", params=params, timeout=10)
        resp.raise_for_status()
        data = resp.json()
        if not data:
            print(f"[{symbol}] No klines for interval={interval}")
            return pd.DataFrame()

        rows = []
        for k in data:
            rows.append(
                {
                    "open_time": datetime.fromtimestamp(k[0] / 1000, tz=timezone.utc),
                    "open": float(k[1]),
                    "high": float(k[2]),
                    "low": float(k[3]),
                    "close": float(k[4]),
                    "volume": float(k[5]),
                }
            )
        df = pd.DataFrame(rows)
        df.set_index("open_time", inplace=True)
        df.sort_index(inplace=True)
        return df
    except Exception as e:
        print(f"[{symbol}] ERROR fetch_klines({interval}): {e}")
        return pd.DataFrame()


# =====================================================
#              INDICATOR├ï & TREND
# =====================================================

def ema(series: pd.Series, period: int) -> pd.Series:
    return series.ewm(span=period, adjust=False).mean()


def rsi(series: pd.Series, period: int = 14) -> pd.Series:
    delta = series.diff()
    gain = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss = (-delta.where(delta < 0, 0)).rolling(window=period).mean()
    rs = gain / loss.replace(0, np.nan)
    return 100 - (100 / (1 + rs))


def calculate_atr(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """
    Llogarit ATR (Average True Range) p├½r volatility measurement.
    """
    high = df['high']
    low = df['low']
    close = df['close']
    
    tr1 = high - low
    tr2 = abs(high - close.shift())
    tr3 = abs(low - close.shift())
    
    tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
    atr = tr.ewm(span=period, adjust=False).mean()
    
    return atr


def calculate_adx(df: pd.DataFrame, period: int = 14) -> float:
    """
    Llogarit ADX p├½r trend strength.
    """
    high = df['high'].values
    low = df['low'].values
    close = df['close'].values
    
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
    if df.empty or len(df) < 50:
        return "neutral"
    
    # Handle both 'Close' and 'close' column names
    close_col = 'Close' if 'Close' in df.columns else 'close'
    
    if close_col not in df.columns:
        return "neutral"
    
    ema8 = df[close_col].ewm(span=8, adjust=False).mean().iloc[-1]
    ema21 = df[close_col].ewm(span=21, adjust=False).mean().iloc[-1]
    ema50 = df[close_col].ewm(span=50, adjust=False).mean().iloc[-1]
    
    # Bullish alignment: EMA8 > EMA21 > EMA50
    if ema8 > ema21 > ema50:
        return "bull"
    # Bearish alignment: EMA8 < EMA21 < EMA50
    elif ema8 < ema21 < ema50:
        return "bear"
    else:
        return "neutral"


def find_support_resistance_levels(df: pd.DataFrame, lookback: int = 100, num_levels: int = 3) -> tuple:
    """
    Gjen nivelet kryesore t├½ support dhe resistance.
    """
    if df.empty or len(df) < lookback:
        return [], []
    
    recent_df = df.iloc[-lookback:]
    highs = recent_df['high'].values
    lows = recent_df['low'].values
    
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
    Kontrollon n├½se ├ºmimi ├½sht├½ af├½r nj├½ niveli S/R.
    """
    for level in levels:
        if abs(price - level) / level <= tolerance:
            return True
    return False


def detect_rsi_divergence(df: pd.DataFrame, rsi_period: int = 14, lookback: int = 20) -> tuple:
    """
    Detekton bullish dhe bearish divergence n├½ RSI.
    """
    if df.empty or len(df) < rsi_period + lookback:
        return False, False
    
    close = df['close']
    rsi_values = rsi(close, rsi_period)
    
    recent_df = df.iloc[-lookback:].copy()
    recent_rsi = rsi_values.iloc[-lookback:].values
    recent_price = recent_df['close'].values
    
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


def detect_trend_1h(df_1h: pd.DataFrame) -> str:
    """
    Trend n├½ 1H me EMA50 dhe EMA200.
    """
    if df_1h.empty or len(df_1h) < 220:
        return "choppy"

    close = df_1h["close"]
    ema50 = ema(close, 50)
    ema200 = ema(close, 200)

    last_close = close.iloc[-1]
    last_ema50 = ema50.iloc[-1]
    last_ema200 = ema200.iloc[-1]

    if last_close > last_ema50 > last_ema200:
        return "bull"
    elif last_close < last_ema50 < last_ema200:
        return "bear"
    else:
        return "choppy"


# =====================================================
#                 ADMIN MONITORING
# =====================================================

def send_heartbeat():
    """
    D├½rgon nj├½ heartbeat te backend q├½ admini t├½ shoh├½ q├½ boti ├½sht├½ gjall├½.
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
            print(f"[HEARTBEAT] Γ¥î {resp.status_code}: {resp.text}")
        else:
            print(f"[HEARTBEAT] Γ£à {BOT_ID}")
    except Exception as e:
        print(f"[HEARTBEAT] ERROR: {e}")


def notify_signal_sent(symbol: str, direction: str):
    """
    Njofton backend-in se ky bot ka d├½rguar sinjal.
    P├½rdoret p├½r /admin/bot_signal dhe p├½r System status n├½ app.
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
            print(f"[BOT_SIGNAL_LOG] Γ¥î {resp.status_code}: {resp.text}")
        else:
            print(f"[BOT_SIGNAL_LOG] Γ£à {symbol} {direction}")
    except Exception as e:
        print(f"[BOT_SIGNAL_LOG] ERROR: {e}")


# =====================================================
#             D├ïRGIMI I SINJALEVE TE BACKEND
# =====================================================

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
    D├½rgon sinjal te FastAPI (tabela kryesore e sinjaleve).
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
            print(f"[BACKEND] Γ¥î Error {resp.status_code}: {resp.text}")
        else:
            data = resp.json()
            print(
                f"[BACKEND] Γ£à Signal saved (id={data.get('id')}): "
                f"{symbol} {direction} {timeframe} "
                f"E={entry:.4f} SL={sl:.4f} TP={tp:.4f}"
            )
    except Exception as e:
        print(f"[BACKEND] Exception sending signal: {e}")


# =====================================================
#                  LOGJIKA E SCALPING
# =====================================================

def analyze_symbol_scalp(symbol: str):
    """
    Strategji e p├½rmir├½suar:
    - Trend 1H (EMA50/EMA200) + ADX
    - Pullback n├½ 5m te EMA20/EMA50
    - RSI(14) 5m oversold/overbought dhe rikthim
    - Volume confirmation
    - RSI Divergence
    - Support/Resistance levels
    - ATR-based dynamic SL/TP
    - 4 nga 6 kushte duhet t├½ jen├½ TRUE
    """

    # 1H p├½r trend
    df_1h = fetch_klines(symbol, interval="1h", limit=250)
    if df_1h.empty:
        return

    trend = detect_trend_1h(df_1h)
    if trend == "choppy":
        # print(f"[{symbol}] Trend choppy, skip.")
        return

    # 5M p├½r entry
    df_5m = fetch_klines(symbol, interval="5m", limit=300)
    if df_5m.empty or len(df_5m) < 50:
        return

    close = df_5m["close"]
    high = df_5m["high"]
    low = df_5m["low"]
    volume = df_5m["volume"]

    ema20 = ema(close, 20)
    ema50 = ema(close, 50)
    rsi14 = rsi(close, 14)
    atr = calculate_atr(df_5m, 14)

    last_close = close.iloc[-1]
    last_high = high.iloc[-1]
    last_low = low.iloc[-1]
    last_volume = volume.iloc[-1]
    last_ema20 = ema20.iloc[-1]
    last_ema50 = ema50.iloc[-1]
    last_rsi = rsi14.iloc[-1]
    last_atr = float(atr.iloc[-1]) if len(atr) > 0 else 0.0

    avg_vol20 = volume.iloc[-20:].mean()
    volume_ratio = last_volume / (avg_vol20 + 0.00001)
    
    # ADX za 5m
    adx_5m = calculate_adx(df_5m, period=14)
    
    # EMA Alignment (NEW - 7th factor)
    ema_alignment = check_ema_alignment(df_5m)
    
    # S/R levels
    support_levels, resistance_levels = find_support_resistance_levels(df_5m, lookback=150)
    
    # RSI Divergence
    bullish_div, bearish_div = detect_rsi_divergence(df_5m, rsi_period=14, lookback=30)
    
    # ATR check
    if last_atr == 0.0 or last_atr < last_close * 0.0005:
        # print(f"[{symbol}] ATR shum├½ i ul├½t, skip.")
        return

    # ======================
    # LONG SCALP KUSHTET (6 pika)
    # ======================
    long_score = 0
    long_reasons = []

    # 1) Trend 1H bullish + ADX
    if trend == "bull":
        long_score += 1
        long_reasons.append(f"Trend_1H_BULL")
        if adx_5m >= MIN_ADX_STRENGTH:
            long_score += 0.5
            long_reasons.append(f"ADX_{adx_5m:.1f}")

    # 2) Pullback te EMA20/EMA50 dhe rikthim lart
    prev_close = close.iloc[-2]
    prev_low = low.iloc[-2]
    prev_ema20 = ema20.iloc[-2]
    prev_ema50 = ema50.iloc[-2]

    if (
        (prev_low < prev_ema20 <= prev_close)
        or (prev_low < prev_ema50 <= prev_close)
    ) and last_close > last_ema20:
        long_score += 1
        long_reasons.append("Pullback_EMA_bounce")

    # 3) RSI oversold -> rikthim
    prev_rsi = rsi14.iloc[-2]
    if prev_rsi < 30 < last_rsi:
        long_score += 1
        long_reasons.append("RSI_oversold_recovery")

    # 4) Volume i lart├½
    if volume_ratio >= MIN_VOLUME_RATIO:
        long_score += 1
        long_reasons.append(f"Vol_{volume_ratio:.2f}x")

    # 5) RSI Bullish Divergence
    if bullish_div:
        long_score += 1
        long_reasons.append("RSI_Bull_Div")
    
    # 6) Jo af├½r resistance
    near_resistance = is_near_sr_level(last_close, resistance_levels, tolerance=0.008)
    if not near_resistance:
        long_score += 0.5
    else:
        long_reasons.append("!Near_RES")
    
    # 7) EMA Alignment
    if ema_alignment == "bull":
        long_score += 1
        long_reasons.append("EMA_ALIGNED")

    # ======================
    # SHORT SCALP KUSHTET (7 pika tani!)
    # ======================
    short_score = 0
    short_reasons = []

    # 1) Trend 1H bearish + ADX
    if trend == "bear":
        short_score += 1
        short_reasons.append(f"Trend_1H_BEAR")
        if adx_5m >= MIN_ADX_STRENGTH:
            short_score += 0.5
            short_reasons.append(f"ADX_{adx_5m:.1f}")

    # 2) Pullback lart te EMA20/50 dhe refuzim posht├½
    prev_high = high.iloc[-2]
    if (
        (prev_high > prev_ema20 >= prev_close)
        or (prev_high > prev_ema50 >= prev_close)
    ) and last_close < last_ema20:
        short_score += 1
        short_reasons.append("Pullback_EMA_rejection")

    # 3) RSI overbought -> rikthim
    if prev_rsi > 70 > last_rsi:
        short_score += 1
        short_reasons.append("RSI_overbought_drop")

    # 4) Volume i lart├½
    if volume_ratio >= MIN_VOLUME_RATIO:
        short_score += 1
        short_reasons.append(f"Vol_{volume_ratio:.2f}x")

    # 5) RSI Bearish Divergence
    if bearish_div:
        short_score += 1
        short_reasons.append("RSI_Bear_Div")
    
    # 6) Jo af├½r support
    near_support = is_near_sr_level(last_close, support_levels, tolerance=0.008)
    if not near_support:
        short_score += 0.5
    else:
        short_reasons.append("!Near_SUP")    
    # 7) EMA Alignment
    if ema_alignment == "bear":
        short_score += 1
        short_reasons.append("EMA_ALIGNED")
    # ======================
    # VENDIMI I SINJALIT
    # ======================

    direction = None
    used_score = 0
    reasons = []

    if long_score >= MIN_SCORE_FOR_SIGNAL and long_score >= short_score:
        if near_resistance:
            print(f"[{symbol}] LONG signal por af├½r resistance, SKIP.")
            return
        direction = "BUY"
        used_score = long_score
        reasons = long_reasons
        
    elif short_score >= MIN_SCORE_FOR_SIGNAL and short_score > long_score:
        if near_support:
            print(f"[{symbol}] SHORT signal por af├½r support, SKIP.")
            return
        direction = "SELL"
        used_score = short_score
        reasons = short_reasons

    if direction is None:
        # print(f"[{symbol}] No strong scalp signal. (long={long_score:.1f}, short={short_score:.1f})")
        return

    now = datetime.now(timezone.utc)
    last_t = last_signal_time.get(symbol)
    if last_t is not None:
        minutes_since = (now - last_t).total_seconds() / 60.0
        if minutes_since < MIN_MINUTES_BETWEEN_SIGNALS:
            # print(f"[{symbol}] {direction} ekziston {minutes_since:.1f} min m├½ par├½, skip.")
            return

    prev_side = last_signal_side.get(symbol)
    if prev_side == direction:
        # print(f"[{symbol}] {direction} sinjal tashm├½ i fundit, skip duplicate.")
        return

    # ===== FIXED PERCENTAGE SL/TP (1.5% SL, 4.5% TP) =====
    entry = last_close
    sl_distance_pct = FIXED_SL_PERCENT / 100.0  # 0.015
    tp_distance_pct = FIXED_TP_PERCENT / 100.0  # 0.045
    
    if direction == "BUY":
        sl = entry * (1 - sl_distance_pct)
        tp = entry * (1 + tp_distance_pct)
    else:  # SELL
        sl = entry * (1 + sl_distance_pct)
        tp = entry * (1 - tp_distance_pct)
    
    # Risk/Reward është automatikisht 4.5/1.5 = 3.0
    risk_reward_ratio = FIXED_TP_PERCENT / FIXED_SL_PERCENT
    
    sl_pct = FIXED_SL_PERCENT
    tp_pct = FIXED_TP_PERCENT

    reasons_text = ", ".join(reasons)
    extra = (
        f"Scalp 5m | Score={used_score:.1f}/6, RR={risk_reward_ratio:.2f}, "
        f"ATR={last_atr:.4f}, ADX={adx_5m:.1f}, Vol={volume_ratio:.2f}x | "
        f"SL={sl_pct:.2f}%, TP={tp_pct:.2f}% | {reasons_text}"
    )

    last_signal_time[symbol] = now
    last_signal_side[symbol] = direction

    local_time_str = now.astimezone(LOCAL_TZ).strftime("%Y-%m-%d %H:%M")
    print(
        f"[{symbol}] ≡ƒÄ» {direction} SCALP @ {entry:.4f} (SL={sl:.4f}, TP={tp:.4f}) | "
        f"Score={used_score:.1f}/6, RR={risk_reward_ratio:.2f}, ADX={adx_5m:.1f} [{local_time_str}]"
    )

    # 1) d├½rgo sinjalin te tabela kryesore
    send_signal_to_backend(
        symbol=symbol,
        direction=direction,
        timeframe="5m",
        entry=entry,
        sl=sl,
        tp=tp,
        extra_text=extra,
    )

    # 2) njofto admin backend-in
    notify_signal_sent(symbol, direction)


# =====================================================
#                      MAIN LOOP
# =====================================================

def main_loop():
    global last_heartbeat_ts

    symbols = fetch_usdt_perpetual_symbols()
    if not symbols:
        print("Γ¥î S'ka simbole USDT-M, po dal.")
        return

    print("≡ƒÜÇ Crypto SCALP bot started.")
    print(f"Source: {SOURCE_NAME}")
    print(f"Analysis type: {ANALYSIS_TYPE}")
    print(f"Symbols: {len(symbols)}  (USDT-M PERPETUAL)")
    print(f"Scan every {SCAN_INTERVAL} seconds.\n")

    # d├½rgo nj├½ heartbeat kur starton
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
                analyze_symbol_scalp(symbol)
            except Exception:
                print(f"[{symbol}] Exception in analyze_symbol_scalp:")
                traceback.print_exc()

        print(f"\nSleeping {SCAN_INTERVAL} seconds...\n")
        time.sleep(SCAN_INTERVAL)


if __name__ == "__main__":
    try:
        main_loop()
    except KeyboardInterrupt:
        print("Stopped by user.")
    except Exception:
        print("Γ¥î Fatal error n├½ bot:")
        traceback.print_exc()
