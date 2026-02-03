<template>
  <section class="grid gap-4 md:grid-cols-3">
    <div class="rounded-3xl border border-white/10 bg-white/5 p-6">
      <p class="text-xs uppercase tracking-[0.3em] text-white/60">Clientes ativos</p>
      <p class="mt-4 text-3xl font-semibold">42</p>
      <p class="mt-2 text-sm text-white/60">Acompanhamentos em andamento</p>
    </div>
    <div class="rounded-3xl border border-white/10 bg-white/5 p-6">
      <p class="text-xs uppercase tracking-[0.3em] text-white/60">Sessões na semana</p>
      <p class="mt-4 text-3xl font-semibold">58</p>
      <p class="mt-2 text-sm text-white/60">Inclui check-ins e retornos</p>
    </div>
    <div class="rounded-3xl border border-white/10 bg-white/5 p-6">
      <p class="text-xs uppercase tracking-[0.3em] text-white/60">Links configurados</p>
      <p class="mt-4 text-3xl font-semibold">36</p>
      <p class="mt-2 text-sm text-white/60">Google Meet conectados</p>
    </div>
  </section>

  <section class="grid gap-6 lg:grid-cols-[1.5fr_1fr]">
    <div class="rounded-3xl border border-white/10 bg-white/5 p-6">
      <div class="flex items-center justify-between">
        <h2 class="text-lg font-semibold">Clientes recentes</h2>
        <button class="rounded-full border border-white/10 px-4 py-1 text-xs text-white/60">Exportar</button>
      </div>
      <div class="mt-6 space-y-4">
        <div v-for="client in clients" :key="client.email" class="rounded-2xl border border-white/10 bg-black/40 px-4 py-4">
          <div class="flex items-center justify-between">
            <p class="font-semibold">{{ client.email }}</p>
            <span class="text-xs text-white/50">{{ client.lastActive }}</span>
          </div>
          <p class="mt-2 text-xs text-white/60">Sessões: {{ client.sessions }}</p>
        </div>
      </div>
    </div>

    <div class="space-y-6">
      <div class="rounded-3xl border border-white/10 bg-gradient-to-br from-aurora/20 to-black/40 p-6">
        <h3 class="text-lg font-semibold">Checklist diário</h3>
        <ul class="mt-4 space-y-3 text-sm">
          <li v-for="item in checklist" :key="item.label" class="flex items-center justify-between rounded-xl border border-white/10 bg-black/40 px-4 py-3">
            <span>{{ item.label }}</span>
            <span class="text-aurora">{{ item.count }}</span>
          </li>
        </ul>
      </div>

      <div class="rounded-3xl border border-white/10 bg-white/5 p-6">
        <h3 class="text-lg font-semibold">Insights rápidos</h3>
        <p class="mt-3 text-sm text-mist">A maioria dos clientes prefere horários entre 18h e 20h.</p>
        <p class="mt-4 text-sm text-mist">Sugestão: abra mais janelas para sessões online.</p>
      </div>
    </div>
  </section>
</template>

<script setup>
const clients = [
  { email: "ana.paula@email.com", sessions: 8, lastActive: "há 2 dias" },
  { email: "pedro.costa@email.com", sessions: 5, lastActive: "há 4 dias" },
  { email: "luana.santos@email.com", sessions: 3, lastActive: "há 1 semana" }
];

const checklist = [
  { label: "Confirmar sessões de amanhã", count: 3 },
  { label: "Enviar mensagens pendentes", count: 5 },
  { label: "Atualizar notas clínicas", count: 2 }
];
</script>
