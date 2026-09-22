import type { ApiHealthStatus, HealthStatus, Item } from "./types";

const API_BASE_URL = import.meta.env.VITE_API_BASE_URL ?? "/api";

async function request<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    headers: { "Content-Type": "application/json" },
    ...init,
  });
  if (!response.ok) {
    throw new Error(`Request to ${path} failed with status ${response.status}`);
  }
  if (response.status === 204) {
    return undefined as T;
  }
  return (await response.json()) as T;
}

export async function fetchBackendHealth(): Promise<HealthStatus> {
  const response = await fetch("/health");
  if (!response.ok) throw new Error("backend /health request failed");
  return response.json();
}

export async function fetchApiHealth(): Promise<ApiHealthStatus> {
  return request<ApiHealthStatus>("/health");
}

export async function fetchItems(): Promise<Item[]> {
  return request<Item[]>("/items");
}

export async function createItem(name: string, description: string): Promise<Item> {
  return request<Item>("/items", {
    method: "POST",
    body: JSON.stringify({ name, description: description || null }),
  });
}

export async function deleteItem(id: number): Promise<void> {
  await request<void>(`/items/${id}`, { method: "DELETE" });
}
