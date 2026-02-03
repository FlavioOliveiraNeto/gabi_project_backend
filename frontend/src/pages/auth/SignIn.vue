<template>
  <div class="space-y-6">
    <div class="space-y-2 text-center">
      <p class="text-xs uppercase tracking-[0.3em] text-aurora">Bem-vindo de volta</p>
      <h1 class="text-2xl font-semibold">Entrar na plataforma</h1>
      <p class="text-sm text-mist">Acesse seus painéis e acompanhe seu progresso.</p>
    </div>

    <form class="space-y-4">
      <div>
        <label class="text-xs uppercase tracking-[0.2em] text-white/60">Email</label>
        <input
          type="email"
          placeholder="voce@email.com"
          class="mt-2 w-full rounded-2xl border border-white/10 bg-black/40 px-4 py-3 text-sm text-white placeholder:text-white/40 focus:border-aurora focus:outline-none"
        />
      </div>
      <div>
        <label class="text-xs uppercase tracking-[0.2em] text-white/60">Senha</label>
        <input
          type="password"
          placeholder="••••••••"
          class="mt-2 w-full rounded-2xl border border-white/10 bg-black/40 px-4 py-3 text-sm text-white placeholder:text-white/40 focus:border-aurora focus:outline-none"
        />
      </div>
      <div class="flex items-center justify-between text-xs text-white/60">
        <label class="flex items-center gap-2">
          <input type="checkbox" class="rounded border-white/20 bg-black/40 text-aurora focus:ring-aurora" />
          Lembrar de mim
        </label>
        <RouterLink to="/auth/recuperar" class="text-aurora">Esqueci minha senha</RouterLink>
      </div>
      <button type="submit" class="w-full rounded-2xl bg-aurora px-6 py-3 text-sm font-semibold text-midnight">
        Entrar
      </button>
    </form>

    <div class="space-y-2 text-center text-sm text-mist">
      <RouterLink to="/auth/cadastro" class="block hover:text-white">Criar nova conta</RouterLink>
      <RouterLink to="/" class="block hover:text-white">Voltar para home</RouterLink>
    </div>
  </div>
</template>
