ADMIN_API_BASE = os.environ.get("ADMIN_API_BASE", "http://127.0.0.1:8000")
# Helper: RSI (Wilder)
def rsi(series, period=14):
    delta = series.diff()
    gain = delta.where(delta > 0, 0.0)
    loss = -delta.where(delta < 0, 0.0)
    avg_gain = gain.ewm(alpha=1/period, min_periods=period, adjust=False).mean()
    avg_loss = loss.ewm(alpha=1/period, min_periods=period, adjust=False).mean()
    rs = avg_gain / (avg_loss + 1e-10)
    return 100 - (100 / (1 + rs))
# BOT/ENV CONFIG
import os
BOT_ID = os.environ.get("BOT_ID", "crypto_scalp_bot")
SOURCE_NAME = os.environ.get("SOURCE_NAME", "crypto_scalp_bot")
ANALYSIS_TYPE = os.environ.get("ANALYSIS_TYPE", "crypto_scalp")
# Helper: get last value from Series or float
def _last(x):
    if hasattr(x, 'iloc'):
        return x.iloc[-1]
    if hasattr(x, '__getitem__') and not isinstance(x, str):
        return x[-1]
    return float(x)
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

# === Helper: fetch_klines with lowercase columns ===
def fetch_klines(symbol, interval, limit=LOOKBACK_BARS):
    # This should return a DataFrame with columns: open, high, low, close, volume, time (all lowercase)
    # Implement your real fetch here. For now, fallback to existing logic if present.
    df = ... # fetch logic here
    df.columns = [c.lower() for c in df.columns]
    return df

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
    last_ema_fast = _last(ema_fast)
    last_ema_slow = _last(ema_slow)
    if trend == "UP" and last_ema_fast > last_ema_slow:
        conf += 1
    elif trend == "DOWN" and last_ema_fast < last_ema_slow:
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
# DEPLOY CHECKLIST (for maintainers)
# 1. Run: python -m py_compile crypto_scalp_bot.py
# 2. Restart bot and tail log to confirm startup
# 3. SCRIPT_VERSION is printed at startup for verification

SCRIPT_VERSION = "2026-01-03-fix-fetch-symbols"

print(f"[STARTUP] crypto_scalp_bot.py version: {SCRIPT_VERSION}")
# =========================
# STRATEGY HELPERS (shared)
# =========================
def ema(series, length):
    return series.ewm(span=length, adjust=False).mean()

def trend_by_ema(df, ema_len=200):
    ema_val = ema(df['close'], ema_len)
    last_close = df['close'].iloc[-1]
    last_ema = ema_val.iloc[-1]
    if last_close > last_ema:
        return "UP"
    elif last_close < last_ema:
        return "DOWN"
    else:
        return "FLAT"

def pullback_touched(df, direction, ema_len=50):
    ema_val = ema(df['close'], ema_len)
    if direction == "UP":
        return (df['close'] < ema_val).iloc[-10:].any()
    elif direction == "DOWN":
        return (df['close'] > ema_val).iloc[-10:].any()
    return False

def detect_pivots(df, left=2, right=2):
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

def hl_lh_bos_trigger(df, direction, left=2, right=2):
    pivot_highs, pivot_lows = detect_pivots(df, left, right)
    if direction == "UP" and len(pivot_lows) >= 2:
        hl1, hl2 = pivot_lows[-2], pivot_lows[-1]
        if df['low'].iloc[hl2] > df['low'].iloc[hl1]:
            # BOS up: price breaks above last pivot high after HL
            for ph in reversed(pivot_highs):
                if ph > hl2:
                    if df['close'].iloc[-1] > df['high'].iloc[ph]:
                        entry = df['close'].iloc[-1]
                        sl = df['low'].iloc[hl2] * 0.999
                        return True, entry, sl
                    break
    if direction == "DOWN" and len(pivot_highs) >= 2:
        lh1, lh2 = pivot_highs[-2], pivot_highs[-1]
        if df['high'].iloc[lh2] < df['high'].iloc[lh1]:
            # BOS down: price breaks below last pivot low after LH
            for pl in reversed(pivot_lows):
                if pl > lh2:
                    if df['close'].iloc[-1] < df['low'].iloc[pl]:
                        entry = df['close'].iloc[-1]
                        sl = df['high'].iloc[lh2] * 1.001
                        return True, entry, sl
                    break
    return False, None, None
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
    Merr të gjitha simbolet USDT-M PERPETUAL nga Binance Futures.
    P.sh. BTCUSDT, ETHUSDT, SOLUSDT, etj.
    """
    try:
        resp = requests.get(f"{BINANCE_FAPI_URL}/fapi/v1/exchangeInfo", timeout=10)
        resp.raise_for_status()
        data = resp.json()
        symbols = []
        for s in data.get("symbols", []):
            if s.get("contractType") == "PERPETUAL" and s.get("quoteAsset") == "USDT":
                symbols.append(s["symbol"])
        return symbols
    except Exception as e:
        print(f"[SYMBOLS] Failed to fetch USDT perpetual symbols: {e}")
        return []


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
    # 1. Get data
    df_4h = fetch_klines(symbol, TF_4H, LOOKBACK_BARS)
    df_1h = fetch_klines(symbol, TF_1H, LOOKBACK_BARS)
    df_entry = fetch_klines(symbol, TF_ENTRY, LOOKBACK_BARS)
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
    price = _last(df_1h['close'])
    last_ema_fast = _last(ema_fast)
    last_ema_slow = _last(ema_slow)
    in_zone = (last_ema_fast <= price <= last_ema_slow) or (last_ema_slow <= price <= last_ema_fast)
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

        # --- SCAN ALL SYMBOLS, SCORE, LIMIT TOP N ---
        signals_candidates = []
        for symbol in symbols:
            try:
                # analyze_symbol_scalp returns (score, symbol, ...)
                result = analyze_symbol_scalp(symbol)
                if result and isinstance(result, dict) and result.get('score', 0) >= MIN_SCORE_FOR_SIGNAL:
                    signals_candidates.append(result)
            except Exception:
                print(f"[{symbol}] Exception in analyze_symbol_scalp:")
                traceback.print_exc()

        # Sort by score descending, take top N
        TOP_N = 3  # configurable
        signals_candidates = sorted(signals_candidates, key=lambda x: x['score'], reverse=True)[:TOP_N]
        for signal in signals_candidates:
            send_signal_to_backend(
                symbol=signal['symbol'],
                direction=signal['direction'],
                timeframe=signal['timeframe'],
                entry=signal['entry'],
                sl=signal['sl'],
                tp=signal['tp'],
                extra_text=signal.get('extra_text', "")
            )
            notify_signal_sent(signal['symbol'], signal['direction'])
            print(f"[BOT] Sent signal: {signal['symbol']} {signal['direction']} score={signal['score']}")

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
