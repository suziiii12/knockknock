"""
Seed script — populates the database with demo data for local development.
Safe to re-run: skips rows that already exist (keyed on unique fields).
"""
from database import engine, SessionLocal
import models

models.Base.metadata.create_all(bind=engine)
db = SessionLocal()


def get_or_create(db, model, defaults=None, **kwargs):
    instance = db.query(model).filter_by(**kwargs).first()
    if instance:
        return instance, False
    instance = model(**kwargs, **(defaults or {}))
    db.add(instance)
    db.flush()
    return instance, True


# ── Buildings ────────────────────────────────────────────────────────────────

walc, _ = get_or_create(db, models.Building,
    name="WALC", defaults={"location": "550 Stadium Mall Dr, West Lafayette, IN"})
hicks, _ = get_or_create(db, models.Building,
    name="Hicks Library", defaults={"location": "504 W State St, West Lafayette, IN"})
haas, _ = get_or_create(db, models.Building,
    name="HAAS Hall", defaults={"location": "403 W State St, West Lafayette, IN"})

print(f"Buildings: {walc.name}, {hicks.name}, {haas.name}")

# ── Users ────────────────────────────────────────────────────────────────────

user1, _ = get_or_create(db, models.User,
    world_id_nullifier_hash="0xaaa111000000000000000000000000000000000000000000000000000000001")
user2, _ = get_or_create(db, models.User,
    world_id_nullifier_hash="0xbbb222000000000000000000000000000000000000000000000000000000002")
user3, _ = get_or_create(db, models.User,
    world_id_nullifier_hash="0xccc333000000000000000000000000000000000000000000000000000000003")

print(f"Users: ids {user1.id}, {user2.id}, {user3.id}")

# ── Challenges ────────────────────────────────────────────────────────────────

sprint, created = get_or_create(db, models.Challenge,
    title="1hr Focus Sprint",
    defaults={
        "duration_minutes": 60,
        "buy_in_amount": 10.0,
        "building_id": walc.id,
        "status": models.ChallengeStatus.active,
        "threshold_score": 70.0,
        "pot_total": 30.0,
    },
)
if created:
    for user in (user1, user2, user3):
        db.add(models.Participant(
            challenge_id=sprint.id,
            user_id=user.id,
            bet_amount=10.0,
        ))

deep, created = get_or_create(db, models.Challenge,
    title="2hr Deep Work",
    defaults={
        "duration_minutes": 120,
        "buy_in_amount": 20.0,
        "building_id": hicks.id,
        "status": models.ChallengeStatus.active,
        "threshold_score": 75.0,
        "pot_total": 40.0,
    },
)
if created:
    for user in (user1, user2):
        db.add(models.Participant(
            challenge_id=deep.id,
            user_id=user.id,
            bet_amount=20.0,
        ))

print(f"Challenges: '{sprint.title}' (id={sprint.id}), '{deep.title}' (id={deep.id})")

# ── Territory scores ──────────────────────────────────────────────────────────

territory_rows = [
    # user1: strong presence in WALC, decent in Hicks
    (user1, walc,  420.0),
    (user1, hicks, 210.0),
    # user2: top of Hicks, some WALC
    (user2, hicks, 380.0),
    (user2, walc,  150.0),
    (user2, haas,   90.0),
    # user3: owns HAAS, visits WALC
    (user3, haas,  310.0),
    (user3, walc,   80.0),
]

for user, building, score in territory_rows:
    row, created = get_or_create(db, models.Territory,
        user_id=user.id, building_id=building.id,
        defaults={"total_score": score},
    )
    if not created and row.total_score == 0.0:
        row.total_score = score

print(f"Territory rows: {len(territory_rows)} inserted/verified")

# ── Commit ────────────────────────────────────────────────────────────────────

db.commit()
db.close()
print("Seed complete.")
