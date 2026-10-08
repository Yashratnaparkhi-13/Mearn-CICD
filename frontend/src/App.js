import React, { useEffect, useState, useCallback } from 'react';
import TodoForm from './components/TodoForm';
import TodoList from './components/TodoList';
import { fetchTodos, createTodo, updateTodo, deleteTodo } from './api';

function App() {
  const [todos, setTodos] = useState([]);
  const [error, setError] = useState(null);

  const loadTodos = useCallback(async () => {
    try {
      const data = await fetchTodos();
      setTodos(data);
      setError(null);
    } catch (err) {
      setError('Could not load todos. Is the backend running?');
    }
  }, []);

  useEffect(() => {
    loadTodos();
  }, [loadTodos]);

  const handleAdd = async (title) => {
    const newTodo = await createTodo(title);
    setTodos((prev) => [newTodo, ...prev]);
  };

  const handleToggle = async (todo) => {
    const updated = await updateTodo(todo._id, { completed: !todo.completed });
    setTodos((prev) => prev.map((t) => (t._id === updated._id ? updated : t)));
  };

  const handleDelete = async (id) => {
    await deleteTodo(id);
    setTodos((prev) => prev.filter((t) => t._id !== id));
  };

  return (
    <div className="app">
      <h1>MERN CI/CD Demo</h1>
      <span className="version-badge">
        v{process.env.REACT_APP_VERSION || 'dev'}
      </span>
      {error && <p role="alert">{error}</p>}
      <TodoForm onAdd={handleAdd} />
      <TodoList todos={todos} onToggle={handleToggle} onDelete={handleDelete} />
    </div>
  );
}

export default App;
