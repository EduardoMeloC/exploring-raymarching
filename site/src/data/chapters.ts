export interface Chapter {
  slug: string;
  title: string;
  description: string;
}

export const chapters: Chapter[] = [
  {
    slug: "01-introduction",
    title: "Introduction",
    description:
      "Context, scope, and methodology of this work on Ray Marching.",
  },
  {
    slug: "02-ray-tracing-vs-ray-marching",
    title: "Ray Tracing vs Ray Marching",
    description:
      "Two ray-based techniques, their trade-offs, and ideal use cases.",
  },
  {
    slug: "03-signed-distance-functions",
    title: "Signed Distance Functions Techniques",
    description:
      "Basic shapes, transformations, boolean operations, domain repetition, and displacement.",
  },
  {
    slug: "04-clouds",
    title: "Clouds",
    description:
      "Volumetric rendering of clouds using density fields, fractal noise, and light approximation.",
  },
  {
    slug: "05-experiments",
    title: "Experiments",
    description:
      "Rendered results showcasing shapes, volumes, domain repetition, and fractals.",
  },
  {
    slug: "06-conclusion",
    title: "Conclusion",
    description: "Summary of the work and directions for future research.",
  },
];

export function getAdjacentChapters(slug: string) {
  const idx = chapters.findIndex((c) => c.slug === slug);
  return {
    prev: idx > 0 ? chapters[idx - 1] : null,
    next: idx < chapters.length - 1 ? chapters[idx + 1] : null,
  };
}
