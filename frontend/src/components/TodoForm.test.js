import React from 'react';
import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import TodoForm from './TodoForm';

describe('TodoForm', () => {
  it('calls onAdd with trimmed title and clears input', async () => {
    const onAdd = jest.fn();
    render(<TodoForm onAdd={onAdd} />);

    const input = screen.getByLabelText(/todo-title/i);
    await userEvent.type(input, '  Buy milk  ');
    await userEvent.click(screen.getByText(/Add/i));

    expect(onAdd).toHaveBeenCalledWith('Buy milk');
    expect(input.value).toBe('');
  });

  it('does not call onAdd for empty input', async () => {
    const onAdd = jest.fn();
    render(<TodoForm onAdd={onAdd} />);
    await userEvent.click(screen.getByText(/Add/i));
    expect(onAdd).not.toHaveBeenCalled();
  });
});
