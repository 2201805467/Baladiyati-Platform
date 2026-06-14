<?php

namespace App\Services;

use App\Models\Category;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;

class ReportImageClassifier
{
    private const MANUAL_REVIEW_THRESHOLD = 50;

    public function classify(UploadedFile $image): array
    {
        $categories = Category::with('department')
            ->where('is_active', true)
            ->orderBy('category_name')
            ->get();

        if ($categories->isEmpty()) {
            return [
                'provider' => 'none',
                'suggested_category' => null,
                'confidence' => 0,
                'needs_manual_review' => true,
                'alternatives' => [],
            ];
        }

        if (config('services.gemini.key')) {
            $geminiResult = $this->classifyWithGemini($image, $categories);

            if ($geminiResult) {
                return $geminiResult;
            }
        }

        return $this->classifyLocally($image, $categories);
    }

    private function classifyWithGemini(UploadedFile $image, \Illuminate\Support\Collection $categories): ?array
    {
        $model = config('services.gemini.model', 'gemini-2.0-flash');
        $endpoint = rtrim(config('services.gemini.endpoint'), '/');
        $url = "{$endpoint}/{$model}:generateContent";

        $categoryLines = $categories
            ->map(fn (Category $category) => sprintf(
                '- id=%d, name="%s", department="%s", description="%s"',
                $category->id,
                $category->category_name,
                $category->department?->dept_name ?? 'unknown',
                $category->description ?? ''
            ))
            ->implode("\n");

        $prompt = "You classify municipality service report images.\n"
            ."Return only strict JSON with: category_id, confidence, reasoning.\n"
            ."Choose exactly one category_id from this list, or null if unclear.\n"
            ."Confidence must be 0-100.\n\n"
            ."Categories:\n{$categoryLines}";

        $response = Http::timeout(20)->post($url.'?key='.config('services.gemini.key'), [
            'contents' => [[
                'parts' => [
                    ['text' => $prompt],
                    [
                        'inline_data' => [
                            'mime_type' => $image->getMimeType() ?: 'image/jpeg',
                            'data' => base64_encode(file_get_contents($image->getRealPath())),
                        ],
                    ],
                ],
            ]],
            'generationConfig' => [
                'temperature' => 0.1,
                'response_mime_type' => 'application/json',
            ],
        ]);

        if (! $response->successful()) {
            return null;
        }

        $text = data_get($response->json(), 'candidates.0.content.parts.0.text');

        if (! is_string($text)) {
            return null;
        }

        $decoded = json_decode($text, true);

        if (! is_array($decoded)) {
            return null;
        }

        $category = $categories->firstWhere('id', (int) ($decoded['category_id'] ?? 0));
        $confidence = max(0, min(100, (int) round((float) ($decoded['confidence'] ?? 0))));

        return $this->resultPayload(
            provider: 'gemini',
            category: $category,
            confidence: $category ? $confidence : 0,
            alternatives: $this->alternatives($categories, $category?->id),
            reasoning: $decoded['reasoning'] ?? null
        );
    }

    private function classifyLocally(UploadedFile $image, \Illuminate\Support\Collection $categories): array
    {
        $haystack = Str::lower($image->getClientOriginalName().' '.$image->getClientMimeType());
        $scored = $categories->map(function (Category $category) use ($haystack) {
            $keywords = $this->keywordsFor($category);
            $score = collect($keywords)->sum(fn (string $keyword) => Str::contains($haystack, $keyword) ? 1 : 0);

            return [
                'category' => $category,
                'score' => $score,
            ];
        })->sortByDesc('score')->values();

        $best = $scored->first();
        $category = ($best['score'] ?? 0) > 0 ? $best['category'] : null;
        $confidence = $category ? min(95, 55 + ($best['score'] * 15)) : 0;

        return $this->resultPayload(
            provider: 'local_keyword',
            category: $category,
            confidence: $confidence,
            alternatives: $this->alternatives($categories, $category?->id),
            reasoning: $category
                ? 'Matched local category keywords from the uploaded file metadata.'
                : 'No confident local keyword match. Manual category selection is recommended.'
        );
    }

    private function resultPayload(string $provider, ?Category $category, int $confidence, array $alternatives, ?string $reasoning): array
    {
        return [
            'provider' => $provider,
            'suggested_category' => $category ? [
                'id' => $category->id,
                'category_name' => $category->category_name,
                'department' => $category->department ? [
                    'id' => $category->department->id,
                    'dept_name' => $category->department->dept_name,
                ] : null,
            ] : null,
            'confidence' => $confidence,
            'needs_manual_review' => ! $category || $confidence < self::MANUAL_REVIEW_THRESHOLD,
            'manual_review_threshold' => self::MANUAL_REVIEW_THRESHOLD,
            'alternatives' => $alternatives,
            'reasoning' => $reasoning,
        ];
    }

    private function alternatives(\Illuminate\Support\Collection $categories, ?int $selectedId): array
    {
        return $categories
            ->reject(fn (Category $category) => $category->id === $selectedId)
            ->take(5)
            ->map(fn (Category $category) => [
                'id' => $category->id,
                'category_name' => $category->category_name,
                'department' => $category->department ? [
                    'id' => $category->department->id,
                    'dept_name' => $category->department->dept_name,
                ] : null,
            ])
            ->values()
            ->all();
    }

    private function keywordsFor(Category $category): array
    {
        $name = Str::lower($category->category_name);
        $description = Str::lower($category->description ?? '');
        $base = preg_split('/[^a-z0-9]+/', $name.' '.$description, -1, PREG_SPLIT_NO_EMPTY) ?: [];

        $domainKeywords = match (true) {
            Str::contains($name, ['pothole', 'road']) => ['pothole', 'hole', 'road', 'street', 'asphalt'],
            Str::contains($name, ['light', 'streetlight']) => ['light', 'lamp', 'streetlight', 'dark'],
            Str::contains($name, ['garbage', 'sanitation']) => ['garbage', 'trash', 'waste', 'rubbish'],
            Str::contains($name, ['tree']) => ['tree', 'fallen', 'branch'],
            Str::contains($name, ['sewage', 'leak']) => ['sewage', 'water', 'leak', 'drain'],
            default => [],
        };

        return array_values(array_unique([...$base, ...$domainKeywords]));
    }
}
