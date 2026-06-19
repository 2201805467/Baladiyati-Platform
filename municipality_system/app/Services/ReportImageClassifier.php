<?php

namespace App\Services;

use App\Models\Category;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class ReportImageClassifier
{
    private const MANUAL_REVIEW_THRESHOLD = 50;
    private ?string $providerFailureReason = null;

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

        if (config('services.groq.key')) {
            $groqResult = $this->classifyWithGroq($image, $categories);

            if ($groqResult) {
                return $groqResult;
            }
        }

        return $this->classifyLocally($image, $categories);
    }

    private function classifyWithGroq(UploadedFile $image, \Illuminate\Support\Collection $categories): ?array
    {
        $model = config('services.groq.model', 'meta-llama/llama-4-scout-17b-16e-instruct');
        $endpoint = config('services.groq.endpoint', 'https://api.groq.com/openai/v1/chat/completions');

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

        $mimeType = $image->getMimeType() ?: 'image/jpeg';
        $base64Image = base64_encode(file_get_contents($image->getRealPath()));

        try {
            $response = Http::withToken(config('services.groq.key'))
                ->acceptJson()
                ->timeout(30)
                ->post($endpoint, [
                    'model' => $model,
                    'messages' => [[
                        'role' => 'user',
                        'content' => [
                            [
                                'type' => 'text',
                                'text' => $prompt,
                            ],
                            [
                                'type' => 'image_url',
                                'image_url' => [
                                    'url' => "data:{$mimeType};base64,{$base64Image}",
                                ],
                            ],
                        ],
                    ]],
                    'temperature' => 0.1,
                    'max_completion_tokens' => 512,
                    'response_format' => ['type' => 'json_object'],
                ]);
        } catch (\Throwable $exception) {
            $this->providerFailureReason = 'Groq request failed: '.$exception->getMessage();
            Log::warning('Groq image classification request failed', [
                'error' => $exception->getMessage(),
            ]);

            return null;
        }

        if (! $response->successful()) {
            $this->providerFailureReason = 'Groq HTTP '.$response->status();
            Log::warning('Groq image classification returned an unsuccessful response', [
                'status' => $response->status(),
                'body' => Str::limit($response->body(), 500),
            ]);

            return null;
        }

        $text = data_get($response->json(), 'choices.0.message.content');

        if (! is_string($text)) {
            $this->providerFailureReason = 'Groq response did not include text output.';
            Log::warning('Groq image classification response had no text output', [
                'response' => $response->json(),
            ]);

            return null;
        }

        $decoded = json_decode($text, true);

        if (! is_array($decoded)) {
            $this->providerFailureReason = 'Groq response was not valid JSON.';
            Log::warning('Groq image classification returned invalid JSON', [
                'text' => Str::limit($text, 500),
            ]);

            return null;
        }

        $category = $categories->firstWhere('id', (int) ($decoded['category_id'] ?? 0));
        $confidence = max(0, min(100, (int) round((float) ($decoded['confidence'] ?? 0))));

        return $this->resultPayload(
            provider: 'groq',
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

        $payload = $this->resultPayload(
            provider: 'local_keyword',
            category: $category,
            confidence: $confidence,
            alternatives: $this->alternatives($categories, $category?->id),
            reasoning: $category
                ? 'Matched local category keywords from the uploaded file metadata.'
                : 'No confident local keyword match. Manual category selection is recommended.'
        );

        if ($this->providerFailureReason && app()->hasDebugModeEnabled()) {
            $payload['provider_failure_reason'] = $this->providerFailureReason;
        }

        return $payload;
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
