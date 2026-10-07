import packageJson from "../../../package.json";

// Prerendered at build time, so the version is the one baked into the image.
// Route handlers are not cached by default since Next.js 15.
export const dynamic = "force-static";

// The deploy script reads `status` and `version` from this body to prove the
// new release is the one answering. Keep exactly these two fields.
export function GET() {
  return Response.json(
    { status: "ok", version: packageJson.version },
    { headers: { "Cache-Control": "no-store" } },
  );
}
