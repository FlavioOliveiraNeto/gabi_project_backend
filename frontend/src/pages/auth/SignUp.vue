<template>
  <div class="space-y-6">
    <div class="space-y-2 text-center">
      <p class="text-xs uppercase tracking-[0.3em] text-aurora">Nova conta</p>
      <h1 class="text-2xl font-semibold">Crie seu acesso</h1>
      <p class="text-sm text-mist">Configure seu painel em poucos minutos.</p>
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
          placeholder="mínimo 8 caracteres"
          class="mt-2 w-full rounded-2xl border border-white/10 bg-black/40 px-4 py-3 text-sm text-white placeholder:text-white/40 focus:border-aurora focus:outline-none"
        />
      </div>
      <div>
        <label class="text-xs uppercase tracking-[0.2em] text-white/60">Confirmar senha</label>
        <input
          type="password"
          placeholder="repita a senha"
          class="mt-2 w-full rounded-2xl border border-white/10 bg-black/40 px-4 py-3 text-sm text-white placeholder:text-white/40 focus:border-aurora focus:outline-none"
        />
      </div>
      <button type="submit" class="w-full rounded-2xl bg-aurora px-6 py-3 text-sm font-semibold text-midnight">
        Criar conta
      </button>
    </form>

    <div class="space-y-2 text-center text-sm text-mist">
      <RouterLink to="/auth/entrar" class="block hover:text-white">Já possui conta? Entrar</RouterLink>
      <RouterLink to="/" class="block hover:text-white">Voltar para home</RouterLink>
    </div>
  </div>
</template>
