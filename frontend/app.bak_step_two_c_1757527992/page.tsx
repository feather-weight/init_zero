export default function Home() {
  return (
    <main>
      <section className="parallax">
        <div className="card container">
          <h1>Wallet Recovery</h1>
          <p>Watch-only, ethical scanning. No sweeping. Recovery only.</p>
          <a className="btn" href="#login">Login</a>
        </div>
      </section>
      <style jsx global>{`
        /* Mobile fallback: disable fixed attachment */
        @media (max-width: 768px) {
          .parallax { background-attachment: scroll; }
        }
      `}</style>
      <section className="container" style={{paddingBottom:'3rem'}}>
        <h2>Purpose, Ethics & Safe Use</h2>
        <p>Use this tool only to recover wallets you rightfully own or are explicitly authorized to help recover.</p>
      </section>
    </main>
  );
}
