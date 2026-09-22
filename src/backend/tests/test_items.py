def test_create_and_list_items(client):
    response = client.post("/api/items", json={"name": "widget", "description": "a test widget"})
    assert response.status_code == 201
    created = response.json()
    assert created["name"] == "widget"

    response = client.get("/api/items")
    assert response.status_code == 200
    items = response.json()
    assert len(items) == 1
    assert items[0]["name"] == "widget"


def test_get_item_not_found(client):
    response = client.get("/api/items/999")
    assert response.status_code == 404


def test_delete_item(client):
    create = client.post("/api/items", json={"name": "temp"})
    item_id = create.json()["id"]

    delete = client.delete(f"/api/items/{item_id}")
    assert delete.status_code == 204

    get_after = client.get(f"/api/items/{item_id}")
    assert get_after.status_code == 404
