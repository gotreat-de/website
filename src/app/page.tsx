import Image from "next/image";

const logoAlt = "GoTreat – Know it. Move it.";
const logoSize = { width: 594, height: 143 };

export default function Home() {
  return (
    <main className="flex flex-1 items-center justify-center px-4 py-16">
      <h1 className="w-full max-w-xl">
        <Image
          src="/brand/logo-slogan-color.svg"
          alt={logoAlt}
          {...logoSize}
          loading="eager"
          className="h-auto w-full dark:hidden"
        />
        <Image
          src="/brand/logo-slogan-negative.svg"
          alt={logoAlt}
          {...logoSize}
          loading="eager"
          className="hidden h-auto w-full dark:block"
        />
      </h1>
    </main>
  );
}
