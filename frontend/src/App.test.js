import React from 'react';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import axios from 'axios';
import App from './App';

jest.mock('axios');

describe('App', () => {
  beforeEach(() => {
    axios.get.mockResolvedValue({ data: [] });
  });

  it('renders the heading', async () => {
    render(<App />);
    expect(screen.getByText(/MERN CI\/CD Demo/i)).toBeInTheDocument();
    await waitFor(() => expect(axios.get).toHaveBeenCalled());
  });

  it('shows empty state message when there are no todos', async () => {
    render(<App />);
    await waitFor(() =>
      expect(screen.getByText(/No todos yet/i)).toBeInTheDocument(),
    );
  });

  it('adds a new todo on form submit', async () => {
    axios.post.mockResolvedValue({
      data: { _id: '1', title: 'Write tests', completed: false },
    });

    render(<App />);
    await waitFor(() => expect(axios.get).toHaveBeenCalled());

    const input = screen.getByLabelText(/todo-title/i);
    await userEvent.type(input, 'Write tests');
    await userEvent.click(screen.getByText(/Add/i));

    await waitFor(() =>
      expect(screen.getByText('Write tests')).toBeInTheDocument(),
    );
  });
});
