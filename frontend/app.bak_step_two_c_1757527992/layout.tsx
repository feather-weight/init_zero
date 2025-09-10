import '../styles/global.scss';
import type { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Wallet Recovery',
  description: 'Ethical, watch-only wallet recovery toolkit',
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
