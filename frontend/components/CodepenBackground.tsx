import React from 'react';

type Props = {
  user: string;
  slug: string;
  title?: string;
  height?: number;
};

export default function CodepenBackground({ user, slug, title = 'CodePen Background', height = 600 }: Props) {
  const src = `https://codepen.io/${user}/embed/preview/${slug}?default-tab=result&theme-id=dark`;
  return (
    <div className="codepen-bg" aria-hidden>
      <iframe
        title={title}
        src={src}
        loading="lazy"
        style={{ width: '100%', height: '100%', border: '0' }}
        allow="fullscreen"
      />
    </div>
  );
}

