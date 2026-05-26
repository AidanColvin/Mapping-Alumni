interface Props {
  url: string;
  label: string;
}

const SOURCE_LABELS: Record<string, string> = {
  wikidata: "Wikidata",
  wikipedia: "Wikipedia",
  sec_filing: "SEC EDGAR",
  company_site: "Company Site",
  university_page: "University Page",
};

export default function SourceLink({ url, label }: Props) {
  if (!url) return null;
  return (
    <a
      href={url}
      target="_blank"
      rel="noopener noreferrer"
      className="text-xs text-blue-500 hover:underline truncate block"
      title={url}
    >
      Source: {SOURCE_LABELS[label] ?? label}
    </a>
  );
}
