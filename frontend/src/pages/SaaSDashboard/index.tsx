import { useQuery } from '@tanstack/react-query'
import { Building2, CalendarDays, Stethoscope, UserRound, UsersRound } from 'lucide-react'

import { getSaaSDashboard } from '@/api/saas'
import { SectionHeader } from '@/components/shared/SectionHeader'
import { Badge } from '@/components/ui/Badge'
import { Card } from '@/components/ui/Card'
import { formatCurrency, formatDate } from '@/utils/format'

function KpiCard(props: { title: string; value: string | number; caption: string }) {
  return (
    <Card>
      <p className="overline">{props.title}</p>
      <p className="mt-2 text-3xl font-bold text-night">{props.value}</p>
      <p className="caption mt-2">{props.caption}</p>
    </Card>
  )
}

export default function SaaSDashboardPage() {
  const { data, isLoading } = useQuery({
    queryKey: ['saas-dashboard'],
    queryFn: getSaaSDashboard,
  })

  if (isLoading || !data) {
    return <p className="body-copy">Carregando visão SaaS...</p>
  }

  return (
    <div className="space-y-5">
      <SectionHeader
        title="Dashboard SaaS"
        subtitle="Visão executiva da operação GoKlinik e da base de clínicas clientes."
      />

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <KpiCard
          title="Clínicas Totais"
          value={data.total_clinics}
          caption={`${data.active_clinics} ativas | ${data.inactive_clinics} inativas`}
        />
        <KpiCard
          title="Novas Clínicas no Mês"
          value={data.new_clinics_this_month}
          caption="Aquisição no mês atual"
        />
        <KpiCard
          title="Pacientes na Plataforma"
          value={data.total_patients}
          caption="Soma de todas as clínicas"
        />
        <KpiCard
          title="Receita do Mês"
          value={formatCurrency(data.total_revenue_this_month)}
          caption="Consolidado pago no período"
        />
      </div>

      <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
        <KpiCard
          title="Vendedores Ativos"
          value={data.active_sellers}
          caption={`${data.total_sellers} vendedores cadastrados`}
        />
        <KpiCard
          title="Convites por Vendedor"
          value={data.seller_invites_sent}
          caption="Total de convites enviados por links"
        />
        <KpiCard
          title="Convites Aceitos"
          value={data.seller_invites_accepted}
          caption="Conversões de convite"
        />
        <KpiCard
          title="Cadastros por Vendedores"
          value={data.seller_signups_completed}
          caption="Clínicas cadastradas por indicação"
        />
      </div>

      <div className="grid gap-4 md:grid-cols-3">
        <Card className="flex items-center gap-3">
          <div className="rounded-lg bg-primary/10 p-2 text-primary">
            <Building2 className="h-5 w-5" />
          </div>
          <div>
            <p className="text-sm font-semibold text-night">Clínicas Ativas</p>
            <p className="caption">{data.active_clinics}</p>
          </div>
        </Card>

        <Card className="flex items-center gap-3">
          <div className="rounded-lg bg-secondary/10 p-2 text-secondary">
            <UsersRound className="h-5 w-5" />
          </div>
          <div>
            <p className="text-sm font-semibold text-night">Masters de Clínica</p>
            <p className="caption">{data.clinic_master_users}</p>
          </div>
        </Card>

        <Card className="flex items-center gap-3">
          <div className="rounded-lg bg-accent/20 p-2 text-amber-700">
            <Stethoscope className="h-5 w-5" />
          </div>
          <div>
            <p className="text-sm font-semibold text-night">Staff Clínico</p>
            <p className="caption">{data.clinical_staff_users}</p>
          </div>
        </Card>
      </div>

      <Card padded={false}>
        <div className="border-b border-slate-100 px-5 py-4">
          <h2 className="section-heading">Top Vendedores</h2>
        </div>
        {data.top_sellers.length === 0 ? (
          <p className="body-copy px-5 py-4">Nenhum vendedor com métricas ainda.</p>
        ) : (
          <div className="divide-y divide-slate-100">
            {data.top_sellers.map((seller) => (
              <div key={seller.id} className="flex flex-wrap items-center justify-between gap-3 px-5 py-3">
                <div className="flex items-center gap-2">
                  <div className="rounded-lg bg-primary/10 p-2 text-primary">
                    <UserRound className="h-4 w-4" />
                  </div>
                  <div>
                    <p className="text-sm font-semibold text-night">{seller.full_name}</p>
                    <p className="caption">
                      Enviados: {seller.invites_sent} | Aceitos: {seller.invites_accepted}
                    </p>
                  </div>
                </div>
                <Badge className="bg-secondary/10 text-secondary">
                  {seller.signups_completed} cadastros
                </Badge>
              </div>
            ))}
          </div>
        )}
      </Card>

      <Card padded={false}>
        <div className="border-b border-slate-100 px-5 py-4">
          <h2 className="section-heading">Clientes Recentes</h2>
        </div>
        <div className="divide-y divide-slate-100">
          {data.recent_clients.map((client) => (
            <div key={client.id} className="flex flex-wrap items-center justify-between gap-3 px-5 py-3">
              <div>
                <p className="text-sm font-semibold text-night">{client.name}</p>
                <p className="caption">
                  {client.slug} | Criada em {formatDate(client.created_at)}
                </p>
              </div>
              <div className="flex items-center gap-2">
                <Badge status={client.is_active ? 'active' : 'inactive'}>
                  {client.is_active ? 'ATIVA' : 'INATIVA'}
                </Badge>
                <Badge className="bg-primary/10 text-primary">{client.plan}</Badge>
                <span className="caption inline-flex items-center gap-1">
                  <CalendarDays className="h-3.5 w-3.5" />
                  {client.primary_contact_email || 'Sem contato principal'}
                </span>
              </div>
            </div>
          ))}
        </div>
      </Card>
    </div>
  )
}
