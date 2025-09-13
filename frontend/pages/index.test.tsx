import { render, screen } from '@testing-library/react'
import Home from './index'

describe('Home page', () => {
  it('renders title and api base text', () => {
    render(<Home />)
    expect(screen.getByText('Step Zero')).toBeInTheDocument()
  })
})
