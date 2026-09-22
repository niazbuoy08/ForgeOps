import type { Item } from "../types";

interface ItemsTableProps {
  items: Item[];
  onDelete: (id: number) => void;
}

export default function ItemsTable({ items, onDelete }: ItemsTableProps) {
  if (items.length === 0) {
    return <p className="empty-state">No records yet. Add one above.</p>;
  }

  return (
    <table className="items-table">
      <thead>
        <tr>
          <th>ID</th>
          <th>Name</th>
          <th>Description</th>
          <th>Created</th>
          <th />
        </tr>
      </thead>
      <tbody>
        {items.map((item) => (
          <tr key={item.id}>
            <td>{item.id}</td>
            <td>{item.name}</td>
            <td>{item.description ?? "—"}</td>
            <td>{new Date(item.created_at).toLocaleString()}</td>
            <td>
              <button onClick={() => onDelete(item.id)} className="btn btn--danger">
                Delete
              </button>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
