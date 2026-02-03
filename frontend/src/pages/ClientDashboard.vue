<template>
  <section class="grid gap-4 md:grid-cols-3">
    <div class="rounded-3xl border border-white/10 bg-white/5 p-6">
      <p class="text-xs uppercase tracking-[0.3em] text-white/60">Sessões realizadas</p>
      <p class="mt-4 text-3xl font-semibold">12</p>
      <p class="mt-2 text-sm text-white/60">Seu ritmo nas últimas semanas</p>
    </div>
    <div class="rounded-3xl border border-white/10 bg-white/5 p-6">
      <p class="text-xs uppercase tracking-[0.3em] text-white/60">Próxima sessão</p>
      <p class="mt-4 text-3xl font-semibold">Seg · 18:00</p>
      <p class="mt-2 text-sm text-white/60">Disponível para ajuste</p>
    </div>
    <div class="rounded-3xl border border-white/10 bg-white/5 p-6">
      <p class="text-xs uppercase tracking-[0.3em] text-white/60">Link de acesso</p>
      <p class="mt-4 text-sm font-semibold text-aurora">meet.google.com/abc-123</p>
      <p class="mt-2 text-sm text-white/60">Receba 10 min antes</p>
    </div>
  </section>

  <section class="grid gap-6 lg:grid-cols-[1.4fr_1fr]">
    <div class="rounded-3xl border border-white/10 bg-white/5 p-6">
      <h2 class="text-lg font-semibold">Sua jornada</h2>
      <div class="mt-5 space-y-4">
        <div class="rounded-2xl border border-white/10 bg-black/40 px-4 py-4">
          <div class="flex items-center justify-between text-sm">
            <span class="text-white/70">Meta da semana</span>
            <span class="text-aurora">80%</span>
          </div>
          <div class="mt-3 h-2 w-full rounded-full bg-white/10">
            <div class="h-2 w-[80%] rounded-full bg-aurora"></div>
          </div>
          <p class="mt-3 text-xs text-white/60">Praticar exercícios de respiração 4x</p>
        </div>
        <div class="rounded-2xl border border-white/10 bg-black/40 px-4 py-4">
          <p class="text-sm text-white/70">Checklist pós sessão</p>
          <ul class="mt-3 space-y-2 text-xs text-white/60">
            <li>✔️ Anotar emoções-chave</li>
            <li>✔️ Registrar gatilhos percebidos</li>
            <li>⬜ Agendar próximo encontro</li>
          </ul>
        </div>
      </div>
    </div>

    <div class="rounded-3xl border border-white/10 bg-white/5 p-6">
      <h2 class="text-lg font-semibold">Mensagens recentes</h2>
      <div class="mt-4 space-y-3 text-sm text-mist">
        <div class="rounded-2xl border border-white/10 bg-black/40 px-4 py-4">
          <p class="font-semibold">Equipe Gabi Care</p>
          <p class="mt-2 text-xs text-white/50">Lembrete: hidratação e relaxamento hoje.</p>
        </div>
        <div class="rounded-2xl border border-white/10 bg-black/40 px-4 py-4">
          <p class="font-semibold">Sua terapeuta</p>
          <p class="mt-2 text-xs text-white/50">Envie dúvidas ou feedbacks pela plataforma.</p>
        </div>
      </div>
    </div>
  </section>
</template>
