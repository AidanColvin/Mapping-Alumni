interface Props {
  label: string;
  variant?: "blue" | "gray" | "green";
}

const CLASSES = {
  blue: "bg-blue-50 text-blue-700",
  gray: "bg-gray-100 text-gray-600",
  green: "bg-green-50 text-green-700",
};

export default function StatsChip({ label, variant = "blue" }: Props) {
  return (
    <span
      className={`inline-block ${CLASSES[variant]} text-xs font-medium px-2 py-0.5 rounded-full capitalize`}
    >
      {label}
    </span>
  );
}
