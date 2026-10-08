from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from datetime import datetime

# Adjust relative imports based on your project structure
from app.core.database import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.trip import Trip, TripMember
from app.schemas.trip import CreateTripRequest, UpdateTripRequest, InviteMemberRequest, GroupPreferencesSchema

router = APIRouter()

@router.get("/me")
def get_my_trips(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    # Retrieve trips where current user is a member
    memberships = db.query(TripMember).filter(TripMember.user_id == current_user.id).all()
    trip_ids = [m.trip_id for m in memberships]
    
    trips = db.query(Trip).filter(Trip.id.in_(trip_ids)).all()
    
    # Needs to be serialized to match your Flutter Trip.fromJson
    # Ensure your SQLAlchemy models have relationships set up correctly to output member info
    return trips

@router.get("/code/{code}")
def find_trip_by_code(code: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    trip = db.query(Trip).filter(Trip.code == code).first()
    if not trip:
        raise HTTPException(status_code=404, detail="Invalid room code")
    if trip.status in ["completed", "cancelled"]:
        raise HTTPException(status_code=410, detail="Room code expired")
    return trip

@router.post("/{code}/join")
def join_trip(code: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    trip = db.query(Trip).filter(Trip.code == code).first()
    if not trip:
        raise HTTPException(status_code=404, detail="Invalid room code")
    
    existing_member = db.query(TripMember).filter(TripMember.trip_id == trip.id, TripMember.user_id == current_user.id).first()
    if existing_member:
        return {"message": "Already a member"}
        
    new_member = TripMember(
        trip_id=trip.id, 
        user_id=current_user.id, 
        status="notReady",
        is_leader=False
    )
    db.add(new_member)
    db.commit()
    db.refresh(trip)
    return {"message": "Successfully joined trip", "trip_id": trip.id}

@router.post("")
def create_trip(payload: CreateTripRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    # Create the trip record
    new_trip = Trip(
        code=payload.code,
        title=payload.title,
        description=payload.description,
        date=payload.date,
        meetup=payload.meetup_name.split(',')[0],
        meetup_full=payload.meetup_name,
        arrival_target=payload.meetup_time,
        wrap_up=payload.wrap_up_time,
        latitude=payload.latitude,
        longitude=payload.longitude,
        status="lobby",
        leader_id=current_user.id
    )
    db.add(new_trip)
    db.commit()
    db.refresh(new_trip)
    
    # Automatically add the creator as leader
    leader_member = TripMember(
        trip_id=new_trip.id,
        user_id=current_user.id,
        is_leader=True,
        status="ready"
    )
    db.add(leader_member)
    db.commit()
    
    # Save preferences to a connected table if you have one, 
    # or return the serialized trip so Flutter can render
    db.refresh(new_trip)
    return new_trip

@router.get("/{trip_id}")
def get_trip(trip_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    trip = db.query(Trip).filter(Trip.id == trip_id).first()
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
    return trip

@router.put("/{trip_id}")
def update_trip(trip_id: str, payload: UpdateTripRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    trip = db.query(Trip).filter(Trip.id == trip_id).first()
    if not trip:
        raise HTTPException(status_code=404, detail="Trip not found")
        
    if trip.leader_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the leader can edit this trip")
        
    for key, value in payload.dict(exclude_unset=True).items():
        setattr(trip, key, value)
        
    db.commit()
    db.refresh(trip)
    return trip

@router.post("/{trip_id}/members/{user_id}/toggle-ready")
def toggle_member_status(trip_id: str, user_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    # You can only toggle yourself unless you are leader overriding
    if current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Cannot toggle another user's status")
        
    member = db.query(TripMember).filter(TripMember.trip_id == trip_id, TripMember.user_id == user_id).first()
    if not member:
        raise HTTPException(status_code=404, detail="Member not found")
        
    # Leader is always ready
    if not member.is_leader:
        member.status = "notReady" if member.status == "ready" else "ready"
        db.commit()
        
    trip = db.query(Trip).filter(Trip.id == trip_id).first()
    return trip

@router.post("/{trip_id}/invite")
def invite_member(trip_id: str, payload: InviteMemberRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    trip = db.query(Trip).filter(Trip.id == trip_id).first()
    if not trip or trip.leader_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the trip leader can invite members")
        
    user_to_invite = db.query(User).filter(User.username == payload.username.lower()).first()
    if not user_to_invite:
        raise HTTPException(status_code=404, detail="User not found")
        
    existing = db.query(TripMember).filter(TripMember.trip_id == trip_id, TripMember.user_id == user_to_invite.id).first()
    if existing:
        raise HTTPException(status_code=400, detail="User is already in this trip")
        
    new_member = TripMember(trip_id=trip_id, user_id=user_to_invite.id, status="notReady", is_leader=False)
    db.add(new_member)
    db.commit()
    
    db.refresh(trip)
    return trip

@router.post("/{trip_id}/start")
def start_trip(trip_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    trip = db.query(Trip).filter(Trip.id == trip_id).first()
    if not trip or trip.leader_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the trip leader can start the trip")
        
    # Check if everyone is ready
    not_ready = db.query(TripMember).filter(TripMember.trip_id == trip_id, TripMember.status != "ready").count()
    if not_ready > 0:
        raise HTTPException(status_code=400, detail="Not all members are ready")
        
    trip.status = "active"
    db.commit()
    db.refresh(trip)
    return trip

@router.post("/{trip_id}/complete")
def complete_trip(trip_id: str, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    trip = db.query(Trip).filter(Trip.id == trip_id).first()
    if not trip or trip.leader_id != current_user.id:
        raise HTTPException(status_code=403, detail="Only the trip leader can complete the trip")
        
    trip.status = "completed"
    db.commit()
    db.refresh(trip)
    return trip