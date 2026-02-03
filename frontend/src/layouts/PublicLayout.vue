<template>
  <div>
    <header class="px-6 pt-6">
      <nav
        class="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-4 rounded-full border border-white/10 bg-black/30 px-4 py-3 backdrop-blur"
      >
        <div class="flex items-center gap-3 text-lg font-semibold">
          <span class="flex h-9 w-9 items-center justify-center rounded-full bg-aurora text-midnight">G</span>
          Gabi Care
        </div>
        <div class="hidden items-center gap-6 text-sm text-mist md:flex">
          <a href="#recursos" class="transition hover:text-white">Recursos</a>
          <a href="#fluxo" class="transition hover:text-white">Fluxo</a>
          <a href="#depoimentos" class="transition hover:text-white">Depoimentos</a>
        </div>
        <div class="flex items-center gap-3 text-sm">
          <RouterLink
            to="/auth/entrar"
            class="rounded-full border border-white/10 px-4 py-2 text-mist transition hover:border-aurora hover:text-white"
          >
            Entrar
          </RouterLink>
          <RouterLink
            to="/auth/cadastro"
            class="rounded-full bg-aurora px-4 py-2 font-semibold text-midnight transition hover:bg-emerald-200"
          >
            Criar conta
          </RouterLink>
        </div>
      </nav>
    </header>
    <main class="mx-auto flex max-w-6xl flex-col gap-20 px-6 pb-20 pt-16">
      <RouterView />
    </main>
  </div>
</template>
