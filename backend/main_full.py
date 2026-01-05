# ...existing code...
from datetime import datetime, timedelta, timezone
from typing import List, Optional, Dict
import os
import smtplib
from email.message import EmailMessage
from zoneinfo import ZoneInfo

import firebase_admin
from firebase_admin import credentials, messaging, auth
from fastapi import FastAPI, Depends, HTTPException, Query, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict
from sqlalchemy import (
    Column,
    Integer,
    String,
    Float,
    DateTime,
    Boolean,
    create_engine,
    func,
    text,
)
from sqlalchemy.orm import sessionmaker, declarative_base, Session

# ======================================================
#                   DATABASE SETUP
# ======================================================

SQLALCHEMY_DATABASE_URL = "sqlite:///./signals.db"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


class Signal(Base):
    __tablename__ = "signals"

    id = Column(Integer, primary_key=True, index=True)

    symbol = Column(String, index=True, nullable=False)
    direction = Column(String, index=True, nullable=False)  # BUY / SELL
    entry = Column(Float, nullable=False)
    tp = Column(Float, nullable=False)
    sl = Column(Float, nullable=False)

    time = Column(DateTime(timezone=True), server_default=func.now(), index=True)

    timeframe = Column(String, index=True, nullable=False)
    source = Column(String, index=True, nullable=False)
    analysis_type = Column(String, index=True, nullable=False)

    status = Column(String, default="open", index=True)  # open / closed
    hit = Column(String, nullable=True)  # "tp", "sl", "manual", "be", etj.
    pnl_percent = Column(Float, nullable=True)

    extra_text = Column(String, nullable=True)


class Device(Base):
    """
    Device për FCM – ruajmë token për të dërguar push.
    """

    __tablename__ = "devices"

    id = Column(Integer, primary_key=True, index=True)
    token = Column(String, unique=True, index=True, nullable=False)
    platform = Column(String, nullable=True)  # p.sh. "android"
    app_version = Column(String, nullable=True)

    created_at = Column(DateTime(timezone=True), server_default=func.now())
    last_seen = Column(DateTime(timezone=True), server_default=func.now())

    enabled = Column(Boolean, default=True, index=True)


class BotStatus(Base):
    """
    Status i botëve/skriptave (heartbeat).
        status = Column(String, default="open", index=True)  # open / closed
        hit = Column(String, nullable=True)  # "tp", "sl", "manual", "be", etj.
        pnl_percent = Column(Float, nullable=True)
        extra_text = Column(String, nullable=True)
        sl_tp_hit_time = Column(DateTime(timezone=True), nullable=True)
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False)
    last_heartbeat = Column(DateTime(timezone=True), nullable=False)
    last_signal_time = Column(DateTime(timezone=True), nullable=True)


class PremiumUser(Base):
    """
    Premium users – email addresses që kanë qasje premium.
    """

    __tablename__ = "premium_users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    tier = Column(String, default="premium", nullable=False)  # "premium", "vip"
    activated_at = Column(DateTime(timezone=True), server_default=func.now())
    expires_at = Column(DateTime(timezone=True), nullable=True)  # NULL = lifetime
    notes = Column(String, nullable=True)


# Krijo tabelat nëse nuk ekzistojnë
Base.metadata.create_all(bind=engine)

# ======================================================
#                FIREBASE ADMIN (SERVER SIDE)
# ======================================================

# ------------- HISTORY ENDPOINT -------------

@app.get("/signals/history", response_model=List[SignalResponse])
def history_signals(limit: int = Query(100, ge=1, le=500), db: Session = Depends(get_db)):
    """
    Kthen sinjalet e mbyllura (closed) për historinë.
    """
    return list_signals(status="closed", limit=limit, db=db)

firebase_app: Optional[firebase_admin.App] = None
try:
    if os.path.exists("firebase-service-account.json"):
        cred = credentials.Certificate("firebase-service-account.json")
        firebase_app = firebase_admin.initialize_app(cred)
        print("Firebase Admin u inicializua.")
    else:
        print(
            "firebase-service-account.json nuk u gjet. "
            "Push notification nga backend NUK do të funksionojë."
        )
except Exception as e:
    print(
        f"Firebase Admin nuk u inicializua: {e}. "
        "Sigurohu që ekziston firebase-service-account.json në këtë folder."
    )
    firebase_app = None

# ======================================================
#                EMAIL / SMTP CONFIG
# ======================================================

SMTP_HOST = "server313.web-hosting.com"
SMTP_PORT = 465  # SSL
SMTP_USER = "official@pannasignals.com"
# Password i email - ndrysho nëse ke password tjetër
SMTP_PASSWORD = os.getenv("EMAIL_PASSWORD", "PannaSignals2024!")
FROM_EMAIL = "Panna Signals <official@pannasignals.com>"


def send_email_smtp(
    to_email: str,
    subject: str,
    html_body: str,
    text_body: Optional[str] = None,
):
    """
    Dërgon email përmes SMTP (Namecheap).
    """
    if SMTP_PASSWORD == "CHANGE_ME_PASSWORD":
        print("[EMAIL] SMTP_PASSWORD nuk është konfiguruar. Email nuk dërgohet.")
        raise RuntimeError("SMTP_PASSWORD nuk është konfiguruar")

    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = FROM_EMAIL
    msg["To"] = to_email

    if not text_body:
        text_body = "Please open this email in an HTML compatible client."

    msg.set_content(text_body)
    msg.add_alternative(html_body, subtype="html")

    try:
        with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT) as server:
            server.login(SMTP_USER, SMTP_PASSWORD)
            server.send_message(msg)
        print(f"[EMAIL] Dërguar te {to_email}")
    except Exception as e:
        print(f"[EMAIL] Error gjatë dërgimit: {e}")
        raise

# ======================================================
#                     Pydantic MODELS
# ======================================================


class SignalBase(BaseModel):
    symbol: str
    direction: str
    entry: float
    tp: float
    sl: float
    time: datetime
    timeframe: str
    source: str
    analysis_type: str
    status: str = "open"
    hit: Optional[str] = None
    pnl_percent: Optional[float] = None
    extra_text: Optional[str] = None


class SignalCreate(BaseModel):
    symbol: str
    direction: str
    entry: float
    tp: float
    sl: float
    time: datetime
    timeframe: str
    source: str
    analysis_type: str
    status: str = "open"
    extra_text: Optional[str] = None
    hit: Optional[str] = None
    pnl_percent: Optional[float] = None


class SignalResponse(SignalBase):
    id: int

    model_config = ConfigDict(from_attributes=True)


class DeviceRegisterIn(BaseModel):
    token: str
    platform: Optional[str] = "android"
    app_version: Optional[str] = None


class DeviceResponse(BaseModel):
    id: int
    token: str
    platform: Optional[str]
    app_version: Optional[str]
    enabled: bool

    model_config = ConfigDict(from_attributes=True)


class StatsResponseModel(BaseModel):
    analysis_type: str
    period: str
    date_from: datetime
    date_to: datetime
    total_trades: int
    wins: int
    losses: int
    breakevens: int
    win_rate: float
    avg_pnl_percent: float
    total_pnl_percent: float


class HealthResponse(BaseModel):
    status: str
    message: str
    db_ok: bool
    firebase_ok: bool


class BotStatusResponse(BaseModel):
    analysis_type: str
    is_active: bool
    last_signal_time: Optional[datetime] = None
    last_signal_symbol: Optional[str] = None
    last_signal_direction: Optional[str] = None
    total_signals_last_24h: int


class HeartbeatIn(BaseModel):
    name: str
    last_signal_time: Optional[datetime] = None


class BotStatusOut(BaseModel):
    name: str
    last_heartbeat: datetime
    last_signal_time: Optional[datetime] = None
    is_online: bool

    model_config = ConfigDict(from_attributes=True)


class VerificationRequest(BaseModel):
    email: str


# ======================================================
#                  FASTAPI APP SETUP
# ======================================================

app = FastAPI(
    title="Signals Backend",
    description="Backend për Forex & Crypto sinjale",
    version="1.0.0",
)

origins = [
    "http://10.0.2.2:8000",   # emulator → backend
    "http://10.0.2.2:36957",  # emulator → Flutter dev server (web)
    "http://127.0.0.1:8000",
    "http://localhost:8000",
    "*",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Dependency për DB në çdo request
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# ======================================================
#           HELPER: SEND PUSH NOTIFICATION
# ======================================================


def send_push_to_all_devices(
    title: str,
    body: str,
    data: Optional[Dict[str, str]],
    db: Session,
):
    """
    Dërgon push notification te të gjithë device-t e regjistruar në tabelën devices.
    """
    if firebase_app is None:
        print("[PUSH] Firebase Admin nuk është inicializuar, skip.")
        return

    devices = db.query(Device).filter(Device.enabled == True).all()
    if not devices:
        print("[PUSH] Nuk ka device të regjistruar (enabled=True), skip.")
        return

    data = data or {}
    str_data = {k: str(v) for k, v in data.items()}

    print(f"[PUSH] Përgatitje push për {len(devices)} device...")

    for d in devices:
        token = d.token
        if not token:
            continue

        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data=str_data,
                token=token,
                android=messaging.AndroidConfig(priority='high'),
                apns=messaging.APNSConfig(headers={'apns-priority': '10'}),
            )
            response = messaging.send(message)
            print(
                f"[PUSH] Dërguar te device id={d.id}, "
                f"token={token[:10]}..., resp={response}"
            )
        except Exception as e:
            print(f"[PUSH] Error te device id={d.id}: {e}")


def send_push_for_signal(db: Session, signal: Signal):
    """
    Ndërton titull/body për push nga një Signal dhe e dërgon te të gjithë device-t.
    """
    title = f"{signal.symbol} {signal.direction} ({signal.timeframe})"

    body = (
        f"Entry: {signal.entry:.5f} | "
        f"TP: {signal.tp:.5f} | "
        f"SL: {signal.sl:.5f}"
    )

    data = {
        "signal_id": str(signal.id),
        "symbol": signal.symbol,
        "direction": signal.direction,
        "timeframe": signal.timeframe,
        "analysis_type": signal.analysis_type or "",
        "source": signal.source or "",
    }

    send_push_to_all_devices(
        title=title,
        body=body,
        data=data,
        db=db,
    )


def send_push_for_signal_close(db, signal, close_type="CLOSE", closed_time_utc=None):
    """
    Dërgon push kur sinjali mbyllet (TP/SL/BE/Manual).
    close_type: "tp", "sl", "be", "manual", "CLOSE"
    closed_time_utc: datetime (UTC) kur u mbyll sinjali
    """
    title = f"{signal.symbol} {signal.direction} ({signal.timeframe}) CLOSED"
    # Format time in Europe/Belgrade
    belgrade_tz = ZoneInfo("Europe/Belgrade")
    if closed_time_utc is None:
        closed_time_utc = datetime.now(timezone.utc)
    closed_time_local = closed_time_utc.astimezone(belgrade_tz)
    time_str = closed_time_local.strftime("%Y-%m-%d %H:%M")
    body = (
        f"Signal CLOSED ({close_type.upper()})\n"
        f"Entry: {signal.entry:.5f} | TP: {signal.tp:.5f} | SL: {signal.sl:.5f}\n"
        f"Closed at: {time_str}"
    )
    data = {
        "signal_id": str(signal.id),
        "symbol": signal.symbol,
        "direction": signal.direction,
        "timeframe": signal.timeframe,
        "analysis_type": signal.analysis_type or "",
        "source": signal.source or "",
        "closed_time": closed_time_utc.isoformat(),
        "close_type": close_type,
    }
    send_push_to_all_devices(
        title=title,
        body=body,
        data=data,
        db=db,
    )
    print(f"[PUSH] Sent close push for signal {signal.id} at {time_str} ({close_type})", flush=True)


# ======================================================
#                     ROUTES
# ======================================================


@app.get("/")
def root():
    return {"message": "Signals backend OK"}


@app.get("/health", response_model=HealthResponse)
def health_check(db: Session = Depends(get_db)):
    """
    Health check për admin: DB + Firebase.
    """
    db_ok = True
    firebase_ok = firebase_app is not None

    try:
        db.execute(text("SELECT 1"))
    except Exception as e:
        print(f"[HEALTH] DB problem: {e}")
        db_ok = False

    status = "ok" if db_ok else "degraded"
    msg = "Backend OK" if db_ok else "Backend ka problem me DB"

    if not firebase_ok:
        msg += " (Firebase jo i inicializuar për push)"

    return HealthResponse(
        status=status,
        message=msg,
        db_ok=db_ok,
        firebase_ok=firebase_ok,
    )


# ------------- EMAIL VERIFICATION VIA SMTP + FIREBASE -------------


@app.post("/auth/send_verification_email")
def send_verification_email(payload: VerificationRequest):
    """
    Gjeneron Firebase email verification link dhe e dërgon me email
    nga official@pannasignals.com përmes SMTP.
    """
    if firebase_app is None:
        raise HTTPException(
            status_code=500,
            detail="Firebase Admin nuk është inicializuar në backend.",
        )

    email = payload.email.strip().lower()
    if not email:
        raise HTTPException(status_code=400, detail="Email është i detyrueshëm.")

    try:
        verification_link = auth.generate_email_verification_link(email)
        print(f"[AUTH] Verification link për {email}: {verification_link}")
    except Exception as e:
        print(f"[AUTH] Error gjatë generate_email_verification_link: {e}")
        raise HTTPException(
            status_code=400,
            detail="Nuk u gjenerua dot verification link. A ekziston ky user në Firebase?",
        )

    subject = "Verify your Panna Signals account"
    text_body = f"Hello,\n\nPlease verify your Panna Signals account by clicking this link:\n{verification_link}\n\nIf you did not create an account, you can ignore this email."
    html_body = f"""
    <html>
      <body style="font-family: Arial, sans-serif; background-color: #0b0f19; color: #ffffff; padding: 20px;">
        <div style="max-width: 480px; margin: 0 auto; background-color: #111827; border-radius: 12px; padding: 24px; border: 1px solid #1f2933;">
          <h2 style="text-align: center; color: #14f4c4; margin-bottom: 8px;">Panna Signals</h2>
          <p style="font-size: 15px;">Hi,</p>
          <p style="font-size: 15px;">
            Tap the button below to verify your email address and activate your Panna Signals account.
          </p>
          <p style="text-align: center; margin: 24px 0;">
            <a href="{verification_link}"
               style="background: linear-gradient(90deg, #14f4c4, #00b4d8); color: #000000;
                      padding: 12px 24px; text-decoration: none; border-radius: 999px;
                      font-weight: 600; font-size: 15px;">
              Verify email
            </a>
          </p>
          <p style="font-size: 13px; color: #9ca3af;">
            Or copy & paste this link in your browser:<br>
            <span style="word-break: break-all; color: #e5e7eb;">{verification_link}</span>
          </p>
          <p style="font-size: 12px; color: #6b7280; margin-top: 24px;">
            If you did not create a Panna Signals account, you can safely ignore this email.
          </p>
        </div>
        <p style="text-align: center; color: #6b7280; font-size: 11px; margin-top: 12px;">
          &copy; {datetime.utcnow().year} Panna Signals. All rights reserved.
        </p>
      </body>
    </html>
    """

    try:
        send_email_smtp(
            to_email=email,
            subject=subject,
            html_body=html_body,
            text_body=text_body,
        )
    except RuntimeError as e:
        raise HTTPException(
            status_code=500,
            detail=str(e),
        )
    except Exception:
        raise HTTPException(
            status_code=500,
            detail="Dështoi dërgimi i email-it të verifikimit.",
        )

    return {"ok": True, "email": email}


# ------------- SIGNALS LIST -------------


@app.get("/signals", response_model=List[SignalResponse])
def list_signals(
    source: Optional[str] = Query(None),
    analysis_type: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
):
    """
    Kthen listën e sinjaleve.
    Filtrat opsional:
    - source (p.sh. forex_scalper_bot)
    - analysis_type (p.sh. forex_scalping, crypto_swing)
    - status (open/closed)
    """
    # Rendit sipas sl_tp_hit_time nëse ekziston, përndryshe sipas time
    from sqlalchemy import case
    q = db.query(Signal).order_by(
        case([(Signal.sl_tp_hit_time != None, Signal.sl_tp_hit_time)], else_=Signal.time).desc()
    )

    if source:
        q = q.filter(Signal.source == source)
    if analysis_type:
        q = q.filter(Signal.analysis_type == analysis_type)
    if status:
        q = q.filter(Signal.status == status)

    signals = q.limit(limit).all()
    return signals


# ------------- CREATE SIGNAL + PUSH -------------


@app.post("/signals", response_model=SignalResponse)
def create_signal(signal_in: SignalCreate, db: Session = Depends(get_db)):
    signal = Signal(
        symbol=signal_in.symbol,
        direction=signal_in.direction,
        entry=signal_in.entry,
        tp=signal_in.tp,
        sl=signal_in.sl,
        time=signal_in.time,
        timeframe=signal_in.timeframe,
        source=signal_in.source,
        analysis_type=signal_in.analysis_type,
        status=signal_in.status,
        hit=signal_in.hit,
        pnl_percent=signal_in.pnl_percent,
        extra_text=signal_in.extra_text,
    )
    db.add(signal)
    db.commit()
    db.refresh(signal)

    # thirr push që sapo u krijua sinjali
    try:
        send_push_for_signal(db, signal)
    except Exception as e:
        print(f"[PUSH] Exception gjatë send_push_for_signal: {e}")

    return signal


# ------------- CLOSE SIGNAL (TP/SL/BE) -------------


@app.post("/signals/{signal_id}/close", response_model=SignalResponse)
def close_signal(
    signal_id: int,
    hit: Optional[str] = None,
    pnl_percent: Optional[float] = None,
    db: Session = Depends(get_db),
):
    """
    Mbyll një sinjal (për tracking TP/SL/BE).
    """
    signal = db.query(Signal).filter(Signal.id == signal_id).first()
    if not signal:
        raise HTTPException(status_code=404, detail="Signal not found")

    from datetime import datetime, timezone
    signal.status = "closed"
    close_event_time_utc = datetime.now(timezone.utc)
    # Do NOT change signal.time (open time)
    signal.closed_time = close_event_time_utc
    signal.sl_tp_hit_time = close_event_time_utc
    close_type = hit if hit is not None else signal.hit if signal.hit else "CLOSE"
    if hit is not None:
        signal.hit = hit
    if pnl_percent is not None:
        signal.pnl_percent = pnl_percent

    db.commit()
    db.refresh(signal)

    try:
        send_push_for_signal_close(db, signal, close_type=close_type, closed_time_utc=close_event_time_utc)
    except Exception as e:
        print(f"[PUSH] Exception gjatë send_push_for_signal_close: {e}", flush=True)

    # Return all times in response
    return {
        "id": signal.id,
        "symbol": signal.symbol,
        "direction": signal.direction,
        "entry": signal.entry,
        "tp": signal.tp,
        "sl": signal.sl,
        "time": signal.time.isoformat() if signal.time else None,
        "closed_time": signal.closed_time.isoformat() if hasattr(signal, 'closed_time') and signal.closed_time else None,
        "sl_tp_hit_time": signal.sl_tp_hit_time.isoformat() if signal.sl_tp_hit_time else None,
        "timeframe": signal.timeframe,
        "source": signal.source,
        "analysis_type": signal.analysis_type,
        "status": signal.status,
        "hit": signal.hit,
        "pnl_percent": signal.pnl_percent,
        "extra_text": signal.extra_text,
    }


# ------------- REGISTER DEVICE (FCM TOKEN) -------------


@app.post("/register_device", response_model=DeviceResponse)
def register_device(device_in: DeviceRegisterIn, db: Session = Depends(get_db)):
    """
    Regjistron (ose përditëson) një device që do të marrë push notifications.
    Kjo thirret nga app-i Flutter me FCM token.
    """
    token = device_in.token.strip()
    if not token:
        raise HTTPException(status_code=400, detail="Token is required")

    device = db.query(Device).filter(Device.token == token).first()
    now = datetime.utcnow()

    if device:
        device.platform = device_in.platform
        device.app_version = device_in.app_version
        device.last_seen = now
        device.enabled = True
    else:
        device = Device(
            token=token,
            platform=device_in.platform,
            app_version=device_in.app_version,
            created_at=now,
            last_seen=now,
            enabled=True,
        )
        db.add(device)

    db.commit()
    db.refresh(device)
    print(f"[DEVICE] Registered token: {device.token[:16]}... (id={device.id})")
    return device


# ------------- STATS -------------


@app.get("/stats", response_model=StatsResponseModel)
def get_stats(
    analysis_type: str = Query(..., description="p.sh. forex_swing, crypto_scalping"),
    period: str = Query("daily", description="daily/weekly/monthly"),
    db: Session = Depends(get_db),
):
    """
    Statistikat për një analysis_type dhe periudhë.
    Merr vetëm sinjalet me status='closed' dhe pnl_percent jo NULL.
    """
    now = datetime.utcnow()

    if period == "daily":
        date_from = now - timedelta(days=1)
    elif period == "weekly":
        date_from = now - timedelta(days=7)
    elif period == "monthly":
        date_from = now - timedelta(days=30)
    else:
        raise HTTPException(status_code=400, detail="Invalid period")

    date_to = now

    q = (
        db.query(Signal)
        .filter(Signal.analysis_type == analysis_type)
        .filter(Signal.status == "closed")
        .filter(Signal.time >= date_from)
        .filter(Signal.time <= date_to)
    )

    signals = q.all()

    total_trades = len(signals)
    wins = 0
    losses = 0
    breakevens = 0
    total_pnl = 0.0

    for s in signals:
        if s.hit:
            h = s.hit.lower()
            if "tp" in h:
                wins += 1
            elif "sl" in h:
                losses += 1
            elif "be" in h:
                breakevens += 1
        if s.pnl_percent is not None:
            total_pnl += s.pnl_percent

    win_rate = (wins / total_trades * 100.0) if total_trades > 0 else 0.0
    avg_pnl = (total_pnl / total_trades) if total_trades > 0 else 0.0

    return StatsResponseModel(
        analysis_type=analysis_type,
        period=period,
        date_from=date_from,
        date_to=date_to,
        total_trades=total_trades,
        wins=wins,
        losses=losses,
        breakevens=breakevens,
        win_rate=win_rate,
        avg_pnl_percent=avg_pnl,
        total_pnl_percent=total_pnl,
    )


# ------------- SEED DEMO SIGNALS -------------


@app.post("/seed_demo")
@app.get("/seed_demo")
def seed_demo(db: Session = Depends(get_db)):
    """
    Krijon disa sinjale demo që t'i shohësh në app.
    Mund ta thërrasësh nga /docs ose një herë nga browser.
    """
    db.query(Signal).filter(Signal.source == "demo_seed").delete()
    db.commit()

    now = datetime.utcnow()

    demo_signals = [
        Signal(
            symbol="EURUSD",
            direction="BUY",
            entry=1.1000,
            tp=1.1040,
            sl=1.0960,
            time=now,
            timeframe="H1",
            source="demo_seed",
            analysis_type="forex_swing",
            status="open",
            extra_text="D1 bull, 4H bull, OB + FVG, score=3/4",
        ),
        Signal(
            symbol="BTCUSDT",
            direction="SELL",
            entry=42000.0,
            tp=41000.0,
            sl=42500.0,
            time=now,
            timeframe="15m",
            source="demo_seed",
            analysis_type="crypto_scalping",
            status="open",
            extra_text="1H bear, pullback to EMA20, high volume.",
        ),
    ]

    db.add_all(demo_signals)
    db.commit()

    return {"inserted": len(demo_signals)}


# ------------- ADMIN STATUS NGA SINJALET (24H) -------------


@app.get("/admin/status", response_model=List[BotStatusResponse])
def admin_status(db: Session = Depends(get_db)):
    """
    Status i thjeshtë për çdo analysis_type:
    - a ka sinjale në 24h e fundit
    - sinjali i fundit (symbol, direction, time).
    Përdoret nga admin për të parë a është gjallë çdo bot.
    """
    now = datetime.utcnow()
    last_24h = now - timedelta(hours=24)

    rows = (
        db.query(Signal)
        .filter(Signal.time >= last_24h)
        .order_by(Signal.analysis_type, Signal.time.desc())
        .all()
    )

    by_type: Dict[str, Dict] = {}

    for s in rows:
        atype = s.analysis_type or "unknown"
        if atype not in by_type:
            by_type[atype] = {
                "analysis_type": atype,
                "last_signal_time": s.time,
                "last_signal_symbol": s.symbol,
                "last_signal_direction": s.direction,
                "total_signals_last_24h": 0,
            }
        by_type[atype]["total_signals_last_24h"] += 1

    result: List[BotStatusResponse] = []
    for atype, info in by_type.items():
        result.append(
            BotStatusResponse(
                analysis_type=atype,
                is_active=info["total_signals_last_24h"] > 0,
                last_signal_time=info["last_signal_time"],
                last_signal_symbol=info["last_signal_symbol"],
                last_signal_direction=info["last_signal_direction"],
                total_signals_last_24h=info["total_signals_last_24h"],
            )
        )

    return result


# ------------- HEARTBEAT NGA SKRIPTAT (LIVE STATUS) -------------


@app.post("/api/heartbeat", response_model=BotStatusOut)
def heartbeat(payload: HeartbeatIn, db: Session = Depends(get_db)):
    """
    Thirret nga skriptat (botet) për të dërguar heartbeat.
    name = emri i botit (p.sh. 'crypto_scalp_bot')
    last_signal_time = koha e sinjalit të fundit (opsionale).
    """
    now = datetime.utcnow()

    bot = db.query(BotStatus).filter(BotStatus.name == payload.name).first()
    if bot is None:
        bot = BotStatus(
            name=payload.name,
            last_heartbeat=now,
            last_signal_time=payload.last_signal_time,
        )
        db.add(bot)
    else:
        bot.last_heartbeat = now
        if payload.last_signal_time is not None:
            bot.last_signal_time = payload.last_signal_time

    db.commit()
    db.refresh(bot)

    is_online = (now - bot.last_heartbeat).total_seconds() < 300  # 5 minuta

    return BotStatusOut(
        name=bot.name,
        last_heartbeat=bot.last_heartbeat,
        last_signal_time=bot.last_signal_time,
        is_online=is_online,
    )


@app.get("/api/admin/bots", response_model=List[BotStatusOut])
def list_bots(db: Session = Depends(get_db)):
    """
    Lista e botëve me status live:
    - is_online (nëse ka heartbeat në 5 minutat e fundit)
    - last_heartbeat
    - last_signal_time (nëse dërgohet nga skripta).
    """
    now = datetime.utcnow()
    bots = db.query(BotStatus).order_by(BotStatus.name).all()

    result: List[BotStatusOut] = []
    for b in bots:
        is_online = (now - b.last_heartbeat).total_seconds() < 300
        result.append(
            BotStatusOut(
                name=b.name,
                last_heartbeat=b.last_heartbeat,
                last_signal_time=b.last_signal_time,
                is_online=is_online,
            )
        )

    return result


@app.post("/upload_bot")
async def upload_bot(file: UploadFile = File(...)):
    """
    Upload bot file në folder /bots
    """
    # Krijo bots directory nëse nuk ekziston
    bots_dir = os.path.join(os.path.dirname(__file__), "bots")
    os.makedirs(bots_dir, exist_ok=True)
    
    # Vetëm .py files
    if not file.filename.endswith('.py'):
        raise HTTPException(status_code=400, detail="Only .py files allowed")
    
    # Ruaj file-in
    file_path = os.path.join(bots_dir, file.filename)
    content = await file.read()
    
    with open(file_path, 'wb') as f:
        f.write(content)
    
    return {
        "success": True,
        "filename": file.filename,
        "path": file_path,
        "size": len(content)
    }


# ======================================================
#           PREMIUM ENDPOINTS
# ======================================================

@app.get("/premium/check/{email}")
async def check_premium_status(email: str, db: Session = Depends(get_db)):
    """
    Kontrollo nëse një email është premium user.
    """
    user = db.query(PremiumUser).filter(PremiumUser.email == email).first()
    
    if not user:
        return {
            "is_premium": False,
            "tier": "free",
            "message": "User is not premium"
        }
    
    # Check nëse ka skaduar
    if user.expires_at and user.expires_at < datetime.now(timezone.utc):
        return {
            "is_premium": False,
            "tier": "free",
            "message": "Premium subscription expired",
            "expired_at": user.expires_at.isoformat()
        }
    
    return {
        "is_premium": True,
        "tier": user.tier,
        "activated_at": user.activated_at.isoformat(),
        "expires_at": user.expires_at.isoformat() if user.expires_at else None,
        "message": "Active premium user"
    }


@app.post("/admin/premium/add")
async def add_premium_user(
    email: str,
    tier: str = "premium",
    expires_days: Optional[int] = None,
    notes: Optional[str] = None,
    db: Session = Depends(get_db)
):
    """
    Admin endpoint për të shtuar premium user.
    tier: "premium" ose "vip"
    expires_days: Sa ditë premium (None = lifetime)
    """
    # Check nëse ekziston
    existing = db.query(PremiumUser).filter(PremiumUser.email == email).first()
    if existing:
        raise HTTPException(status_code=400, detail="User already premium")
    
    expires_at = None
    if expires_days:
        expires_at = datetime.now(timezone.utc) + timedelta(days=expires_days)
    
    new_user = PremiumUser(
        email=email,
        tier=tier,
        expires_at=expires_at,
        notes=notes
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return {
        "success": True,
        "email": email,
        "tier": tier,
        "expires_at": expires_at.isoformat() if expires_at else "lifetime"
    }


@app.get("/admin/premium/list")
async def list_premium_users(db: Session = Depends(get_db)):
    """
    Lista e të gjithë premium users.
    """
    users = db.query(PremiumUser).all()
    return [
        {
            "id": u.id,
            "email": u.email,
            "tier": u.tier,
            "activated_at": u.activated_at.isoformat(),
            "expires_at": u.expires_at.isoformat() if u.expires_at else "lifetime",
            "notes": u.notes
        }
        for u in users
    ]
