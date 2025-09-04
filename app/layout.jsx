export const metadata = {
  title: "Next.js Blue/Green Demo",
  description: "Root layout for Next.js App Router",
};

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <head>
        <link rel="stylesheet" href="/style.css" />
      </head>
      <body style={{ margin: 0, fontFamily: 'system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif' }}>
        {children}
      </body>
    </html>
  );
}