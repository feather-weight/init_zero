import React from 'react';
type Props = { className?: string; children?: React.ReactNode };
export default function Parallax({ className = '', children }: Props) {
  return (
    <section className={`parallax ${className}`} role="img" aria-label="Decorative parallax background">
      <div>{children}</div>
    </section>
  );
}
