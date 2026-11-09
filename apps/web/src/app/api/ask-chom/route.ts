import { answerStudyQuestion } from '@/lib/ask-chom';

export const runtime = 'nodejs';
export const maxDuration = 30;

export async function POST(request: Request) {
  // Vercel rotates its injected OIDC credential; read it on every invocation.
  const token =
    process.env.AI_GATEWAY_API_KEY ||
    (process.env.VERCEL === '1' ? request.headers.get('x-vercel-oidc-token') : undefined) ||
    process.env.VERCEL_OIDC_TOKEN;
  return answerStudyQuestion(request, token);
}
