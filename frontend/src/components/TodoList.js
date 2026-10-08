import React from 'react';
import PropTypes from 'prop-types';

function TodoList({ todos, onToggle, onDelete }) {
  if (!todos.length) {
    return <p>No todos yet. Create one above!</p>;
  }

  return (
    <ul className="todo-list">
      {todos.map((todo) => (
        <li
          key={todo._id}
          className={`todo-item ${todo.completed ? 'completed' : ''}`}
        >
          <span onClick={() => onToggle(todo)} role="presentation">
            {todo.title}
          </span>
          <button type="button" onClick={() => onDelete(todo._id)}>
            Delete
          </button>
        </li>
      ))}
    </ul>
  );
}

TodoList.propTypes = {
  todos: PropTypes.arrayOf(
    PropTypes.shape({
      _id: PropTypes.string.isRequired,
      title: PropTypes.string.isRequired,
      completed: PropTypes.bool,
    }),
  ).isRequired,
  onToggle: PropTypes.func.isRequired,
  onDelete: PropTypes.func.isRequired,
};

export default TodoList;
