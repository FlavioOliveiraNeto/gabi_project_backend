<template>
  <section class="grid gap-10 lg:grid-cols-[1.2fr_0.8fr] lg:items-center">
    <div class="space-y-6">
      <p class="text-xs uppercase tracking-[0.3em] text-aurora">Clínica digital moderna</p>
      <h1 class="text-4xl font-semibold leading-tight md:text-5xl">
        Crie jornadas terapêuticas com dados, empatia e automação.
      </h1>
      <p class="text-lg text-mist">
        Um hub inteligente para terapeutas acompanharem clientes, organizarem sessões e oferecerem uma
        experiência mobile-first impecável.
      </p>
      <div class="flex flex-wrap items-center gap-4">
        <RouterLink
          to="/auth/cadastro"
          class="rounded-full bg-aurora px-6 py-3 text-sm font-semibold text-midnight"
        >
          Começar agora
        </RouterLink>
        <RouterLink
          to="/dashboard/admin"
          class="rounded-full border border-white/10 px-6 py-3 text-sm font-semibold text-white hover:border-aurora"
        >
          Ver dashboards
        </RouterLink>
      </div>
      <div class="flex items-center gap-6 text-sm text-white/60">
        <div>
          <p class="text-2xl font-semibold text-white">+120%</p>
          <p>retenção em 90 dias</p>
        </div>
        <div>
          <p class="text-2xl font-semibold text-white">4.9/5</p>
          <p>satisfação mobile</p>
        </div>
        <div>
          <p class="text-2xl font-semibold text-white">24h</p>
          <p>tempo médio de setup</p>
        </div>
      </div>
    </div>
    <div class="rounded-3xl border border-white/10 bg-white/5 p-6 shadow-xl">
      <div class="flex items-center justify-between">
        <p class="text-sm text-white/60">Próximas sessões</p>
        <span class="rounded-full bg-aurora/20 px-3 py-1 text-xs text-aurora">Ao vivo</span>
      </div>
      <div class="mt-6 space-y-4">
        <div class="rounded-2xl border border-white/10 bg-black/40 px-4 py-4">
          <div class="flex items-center justify-between">
            <p class="font-semibold">Ana Paula</p>
            <span class="text-xs text-white/50">Hoje · 14:00</span>
          </div>
          <p class="mt-2 text-sm text-white/60">Sessão de acompanhamento · Google Meet</p>
        </div>
        <div class="rounded-2xl border border-white/10 bg-black/40 px-4 py-4">
          <div class="flex items-center justify-between">
            <p class="font-semibold">Pedro Costa</p>
            <span class="text-xs text-white/50">Amanhã · 09:00</span>
          </div>
          <p class="mt-2 text-sm text-white/60">Triagem inicial · Presencial</p>
        </div>
        <div class="rounded-2xl border border-dashed border-white/20 px-4 py-6 text-center text-sm text-white/50">
          Conecte seu calendário e sincronize em tempo real.
        </div>
      </div>
    </div>
  </section>

  <section id="recursos" class="grid gap-6 md:grid-cols-3">
    <div v-for="feature in features" :key="feature.title" class="rounded-3xl border border-white/10 bg-white/5 p-6">
      <h3 class="text-lg font-semibold">{{ feature.title }}</h3>
      <p class="mt-3 text-sm text-mist">{{ feature.description }}</p>
    </div>
  </section>

  <section id="fluxo" class="grid gap-10 lg:grid-cols-[0.7fr_1.3fr]">
    <div class="space-y-4">
      <p class="text-xs uppercase tracking-[0.3em] text-aurora">Fluxo guiado</p>
      <h2 class="text-3xl font-semibold">Uma jornada coesa do primeiro contato ao acompanhamento.</h2>
      <p class="text-base text-mist">
        O painel unificado garante que terapeuta e cliente tenham clareza sobre metas, sessões e
        comunicação, com todas as interações sincronizadas.
      </p>
      <RouterLink
        to="/dashboard/cliente"
        class="inline-flex items-center gap-2 rounded-full border border-white/10 px-5 py-2 text-sm text-white hover:border-aurora"
      >
        Ver painel do cliente
      </RouterLink>
    </div>
    <div class="grid gap-4 md:grid-cols-2">
      <div v-for="step in steps" :key="step.title" class="rounded-3xl border border-white/10 bg-white/5 p-6">
        <p class="text-sm text-aurora">{{ step.number }}</p>
        <h3 class="mt-3 text-lg font-semibold">{{ step.title }}</h3>
        <p class="mt-2 text-sm text-mist">{{ step.description }}</p>
      </div>
    </div>
  </section>

  <section id="depoimentos" class="rounded-3xl border border-white/10 bg-white/5 p-8">
    <div class="flex flex-col gap-6 lg:flex-row lg:items-center lg:justify-between">
      <div>
        <p class="text-xs uppercase tracking-[0.3em] text-aurora">Depoimentos</p>
        <h2 class="mt-3 text-3xl font-semibold">Experiências elogiadas por terapeutas e clientes.</h2>
      </div>
      <div class="flex flex-col gap-4 md:flex-row">
        <div class="rounded-2xl border border-white/10 bg-black/40 px-5 py-4">
          <p class="text-sm text-mist">"Passei a ter visão clara da minha agenda e evolução."</p>
          <p class="mt-2 text-xs text-white/50">Camila · Terapeuta</p>
        </div>
        <div class="rounded-2xl border border-white/10 bg-black/40 px-5 py-4">
          <p class="text-sm text-mist">"Consigo acompanhar metas e sessões sem esforço."</p>
          <p class="mt-2 text-xs text-white/50">Henrique · Cliente</p>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup>
const features = [
  {
    title: "Jornadas guiadas por dados",
    description: "Fluxos inteligentes para triagem, sessões e acompanhamento com métricas sempre à vista."
  },
  {
    title: "Experiência cuidadosa",
    description: "Design leve, foco em empatia e comunicação clara em qualquer dispositivo."
  },
  {
    title: "Automação segura",
    description: "Lembretes, documentos e anotações com segurança e rastreabilidade."
  }
];

const steps = [
  {
    number: "01",
    title: "Onboarding inteligente",
    description: "Colete dados iniciais e personalize o plano terapêutico."
  },
  {
    number: "02",
    title: "Sessões integradas",
    description: "Links de reunião, notas clínicas e acompanhamento contínuo."
  },
  {
    number: "03",
    title: "Insights de progresso",
    description: "Dashboards e alertas para monitorar evolução."
  },
  {
    number: "04",
    title: "Comunicação fluida",
    description: "Mensagens seguras e lembretes automáticos."
  }
];
</script>
