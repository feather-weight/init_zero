import Head from 'next/head';
import React from 'react';
import styles from '../styles/starfield.module.scss';

type Props = {
  children?: React.ReactNode;
};

export default function Starfield({ children }: Props) {
  return (
    <section className={styles.starfield} aria-label="Animated starfield background">
      <Head>
        <link
          href="https://fonts.googleapis.com/css?family=Lato:300,400,700"
          rel="stylesheet"
        />
      </Head>
      <div className={styles.stars} />
      <div className={styles.stars2} />
      <div className={styles.stars3} />
      <div className={styles.starTitle}>
        {children}
      </div>
    </section>
  );
}
