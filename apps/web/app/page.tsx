import SearchBar from "../components/search-bar";

export default function Home() {
  return (
    <main className="flex flex-col items-center justify-center min-h-screen gap-8 px-4">
      <h1 className="text-4xl font-bold tracking-tight">AlumniMap</h1>
      <p className="text-gray-500 text-lg">
        Discover where alumni from any university work and lead.
      </p>
      <SearchBar />
    </main>
  );
}
