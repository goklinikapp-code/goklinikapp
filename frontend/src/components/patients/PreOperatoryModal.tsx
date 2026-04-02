import type { ReactNode } from 'react'

import { Badge } from '@/components/ui/Badge'
import { Modal } from '@/components/ui/Modal'
import type { PreOperatoryRecord } from '@/types'
import { resolveMediaUrl } from '@/utils/mediaUrl'
import { preOperatoryStatusLabel } from '@/components/patients/preOperatoryStatus'

function preOperatoryStatusBadgeClass(status?: PreOperatoryRecord['status']) {
  if (status === 'approved') return 'bg-success/15 text-success'
  if (status === 'rejected') return 'bg-danger/15 text-danger'
  if (status === 'in_review') return 'bg-amber-100 text-amber-700'
  return 'bg-slate-200 text-slate-600'
}

interface PreOperatoryModalProps {
  isOpen: boolean
  onClose: () => void
  title?: string
  className?: string
  record?: PreOperatoryRecord | null
  isLoading?: boolean
  isError?: boolean
  loadingMessage?: string
  errorMessage?: string
  emptyMessage?: string
  allowPhotoDelete?: boolean
  deletingPhotoId?: string | null
  onDeletePhoto?: (photoId: string) => void
  actionArea?: ReactNode
}

export function PreOperatoryModal({
  isOpen,
  onClose,
  title = 'Pré-operatório',
  className = 'max-w-5xl',
  record,
  isLoading = false,
  isError = false,
  loadingMessage = 'Carregando pré-operatório...',
  errorMessage = 'Não foi possível carregar o pré-operatório agora.',
  emptyMessage = 'Nenhum pré-operatório enviado para este paciente.',
  allowPhotoDelete = false,
  deletingPhotoId,
  onDeletePhoto,
  actionArea,
}: PreOperatoryModalProps) {
  const statusText = preOperatoryStatusLabel(record?.status)

  return (
    <Modal
      isOpen={isOpen}
      onClose={onClose}
      title={title}
      className={className}
    >
      {isLoading ? (
        <p className="text-sm text-slate-500">{loadingMessage}</p>
      ) : isError ? (
        <p className="text-sm text-slate-500">{errorMessage}</p>
      ) : !record ? (
        <p className="text-sm text-slate-500">{emptyMessage}</p>
      ) : (
        <div className="space-y-4">
          <div className="flex items-center justify-between rounded-card border border-slate-200 bg-slate-50 p-3">
            <p className="text-sm font-semibold text-night">Status da triagem</p>
            <Badge className={preOperatoryStatusBadgeClass(record.status)}>{statusText}</Badge>
          </div>

          <div className="grid gap-3 md:grid-cols-2">
            <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
              <p className="overline">Alergias</p>
              <p className="text-sm text-slate-700">{record.allergies?.trim() || 'Não informado'}</p>
            </div>
            <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
              <p className="overline">Medicamentos em uso</p>
              <p className="text-sm text-slate-700">{record.medications?.trim() || 'Não informado'}</p>
            </div>
            <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
              <p className="overline">Cirurgias anteriores</p>
              <p className="text-sm text-slate-700">{record.previous_surgeries?.trim() || 'Não informado'}</p>
            </div>
            <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
              <p className="overline">Doenças</p>
              <p className="text-sm text-slate-700">{record.diseases?.trim() || 'Não informado'}</p>
            </div>
            <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
              <p className="overline">Altura</p>
              <p className="text-sm text-slate-700">
                {record.height != null ? `${record.height} m` : 'Não informado'}
              </p>
            </div>
            <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
              <p className="overline">Peso</p>
              <p className="text-sm text-slate-700">
                {record.weight != null ? `${record.weight} kg` : 'Não informado'}
              </p>
            </div>
            <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
              <p className="overline">Fuma</p>
              <p className="text-sm text-slate-700">{record.smoking ? 'Sim' : 'Não'}</p>
            </div>
            <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
              <p className="overline">Consome álcool</p>
              <p className="text-sm text-slate-700">{record.alcohol ? 'Sim' : 'Não'}</p>
            </div>
          </div>

          <div className="rounded-card border border-slate-200 bg-slate-50 p-3">
            <p className="overline">Observações da clínica</p>
            <p className="text-sm text-slate-700">{record.notes?.trim() || 'Sem observações.'}</p>
          </div>

          <div>
            <p className="mb-2 text-sm font-semibold text-night">Fotos enviadas</p>
            {(record.photos || []).length === 0 ? (
              <p className="text-sm text-slate-500">Nenhuma foto enviada.</p>
            ) : (
              <div className="flex flex-wrap gap-2">
                {record.photos.map((item) => (
                  <div
                    key={item.id}
                    className="relative h-20 w-20 overflow-hidden rounded-md border border-slate-200"
                  >
                    <a href={resolveMediaUrl(item.file_url)} target="_blank" rel="noreferrer">
                      <img
                        src={resolveMediaUrl(item.file_url)}
                        alt="Foto pré-operatória"
                        className="h-full w-full object-cover"
                      />
                    </a>
                    {allowPhotoDelete ? (
                      <button
                        type="button"
                        className="absolute right-1 top-1 rounded-full bg-red-600 px-1.5 py-0.5 text-[10px] font-semibold text-white hover:bg-red-700 disabled:cursor-not-allowed disabled:opacity-60"
                        onClick={() => onDeletePhoto?.(item.id)}
                        disabled={deletingPhotoId === item.id}
                        title="Remover imagem"
                      >
                        {deletingPhotoId === item.id ? '...' : 'X'}
                      </button>
                    ) : null}
                  </div>
                ))}
              </div>
            )}
          </div>

          <div>
            <p className="mb-2 text-sm font-semibold text-night">Documentos enviados</p>
            {(record.documents || []).length === 0 ? (
              <p className="text-sm text-slate-500">Nenhum documento enviado.</p>
            ) : (
              <div className="flex flex-wrap gap-2">
                {record.documents.map((item, index) => (
                  <a
                    key={item.id}
                    href={resolveMediaUrl(item.file_url)}
                    target="_blank"
                    rel="noreferrer"
                    className="inline-flex items-center rounded-md border border-slate-200 px-3 py-2 text-sm text-primary hover:bg-tealIce"
                  >
                    Documento {index + 1}
                  </a>
                ))}
              </div>
            )}
          </div>

          {actionArea ? <div className="rounded-card border border-slate-200 bg-white p-4">{actionArea}</div> : null}
        </div>
      )}
    </Modal>
  )
}
