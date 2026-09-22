from sqlalchemy import select
from sqlalchemy.orm import Session

from app import models, schemas


def list_items(db: Session) -> list[models.Item]:
    return list(db.scalars(select(models.Item).order_by(models.Item.id)))


def get_item(db: Session, item_id: int) -> models.Item | None:
    return db.get(models.Item, item_id)


def create_item(db: Session, item: schemas.ItemCreate) -> models.Item:
    db_item = models.Item(name=item.name, description=item.description)
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item


def delete_item(db: Session, item_id: int) -> bool:
    db_item = get_item(db, item_id)
    if db_item is None:
        return False
    db.delete(db_item)
    db.commit()
    return True
