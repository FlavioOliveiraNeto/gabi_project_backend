<template>
  <div class="min-h-screen bg-midnight">
    <header class="border-b border-white/10 bg-black/30 px-6 py-6 backdrop-blur">
      <div class="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-4">
        <div>
          <p class="text-xs uppercase tracking-[0.3em] text-aurora">Dashboards</p>
          <h1 class="text-3xl font-semibold">Painel da clínica</h1>
        </div>
        <div class="flex items-center gap-3">
          <RouterLink
            to="/"
            class="rounded-full border border-white/10 px-5 py-2 text-sm text-mist hover:border-aurora"
          >
            Voltar para home
          </RouterLink>
          <RouterLink
            to="/auth/entrar"
            class="rounded-full bg-aurora px-5 py-2 text-sm font-semibold text-midnight"
          >
            Trocar acesso
          </RouterLink>
        </div>
      </div>
    </header>
    <main class="mx-auto flex max-w-6xl flex-col gap-8 px-6 py-10">
      <RouterView />
    </main>
  </div>
</template>
