import { useEffect, useState } from "react";

import { createItem, deleteItem, fetchApiHealth, fetchBackendHealth, fetchItems } from "./api";
import "./App.css";
import ItemsTable from "./components/ItemsTable";
import StatusCard from "./components/StatusCard";
import type { ApiHealthStatus, HealthStatus, Item } from "./types";

const APP_VERSION = import.meta.env.VITE_APP_VERSION ?? "dev-local";

export default function App() {
  const [backendHealth, setBackendHealth] = useState<HealthStatus | null>(null);
  const [apiHealth, setApiHealth] = useState<ApiHealthStatus | null>(null);
  const [items, setItems] = useState<Item[]>([]);
  const [name, setName] = useState("");
  const [description, setDescription] = useState("");
  const [error, setError] = useState<string | null>(null);

  const refresh = async () => {
    try {
      const [health, apiHealthResult, itemsResult] = await Promise.all([
        fetchBackendHealth(),
        fetchApiHealth(),
        fetchItems(),
      ]);
      setBackendHealth(health);
      setApiHealth(apiHealthResult);
      setItems(itemsResult);
      setError(null);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed to reach backend");
    }
  };

  useEffect(() => {
    refresh();
    const interval = setInterval(refresh, 15000);
    return () => clearInterval(interval);
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;
    await createItem(name.trim(), description.trim());
    setName("");
    setDescription("");
    await refresh();
  };

  const handleDelete = async (id: number) => {
    await deleteItem(id);
    await refresh();
  };

  return (
    <div className="dashboard">
      <header className="dashboard__header">
        <h1>AKS GitOps Platform</h1>
        <p className="dashboard__subtitle">Production style three-tier application dashboard</p>
      </header>

      {error && <div className="banner banner--error">{error}</div>}

      <section className="status-grid">
        <StatusCard label="Application" value="Running" tone="ok" />
        <StatusCard
          label="Backend Health"
          value={backendHealth?.status ?? "unknown"}
          tone={backendHealth?.status === "ok" ? "ok" : "error"}
        />
        <StatusCard
          label="Database Health"
          value={apiHealth?.database ?? "unknown"}
          tone={apiHealth?.database === "ok" ? "ok" : "error"}
        />
        <StatusCard label="Environment" value={apiHealth?.environment ?? "unknown"} tone="neutral" />
        <StatusCard label="Backend Version" value={apiHealth?.version ?? "unknown"} tone="neutral" />
        <StatusCard label="Frontend Version" value={APP_VERSION} tone="neutral" />
      </section>

      <section className="panel">
        <h2>Sample Records</h2>
        <form onSubmit={handleSubmit} className="item-form">
          <input
            placeholder="Name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            required
          />
          <input
            placeholder="Description (optional)"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
          />
          <button type="submit" className="btn btn--primary">
            Add Item
          </button>
        </form>
        <ItemsTable items={items} onDelete={handleDelete} />
      </section>
    </div>
  );
}
