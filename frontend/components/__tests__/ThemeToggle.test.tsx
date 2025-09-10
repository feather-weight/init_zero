import { render, screen, fireEvent } from '@testing-library/react';
import ThemeToggle from '../ThemeToggle';

describe('ThemeToggle', () => {
  it('renders a toggle button and switches label', () => {
    render(<ThemeToggle />);
    const btn = screen.getByRole('button');
    expect(btn).toBeInTheDocument();

    const initial = btn.textContent;
    fireEvent.click(btn);
    expect(btn.textContent).not.toBe(initial);
  });
});

