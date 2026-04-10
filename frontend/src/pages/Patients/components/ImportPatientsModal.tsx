import { useMemo, useRef, useState, type DragEventHandler } from 'react'
import { useMutation } from '@tanstack/react-query'
import { isAxiosError } from 'axios'
import { Download, FileSpreadsheet, Loader2, Upload } from 'lucide-react'
import toast from 'react-hot-toast'

import { importPatients, type PatientsImportResponse } from '@/api/patients'
import { Button } from '@/components/ui/Button'
import { Modal } from '@/components/ui/Modal'

interface ImportPatientsModalProps {
  isOpen: boolean
  onClose: () => void
  onImported?: (result: PatientsImportResponse) => void
}

const TEMPLATE_FILENAME = 'modelo_importacao_pacientes.csv'
const TEMPLATE_CONTENT = 'nome,email,telefone\nJoao Silva,joao@email.com,11999999999\n'

export function ImportPatientsModal({ isOpen, onClose, onImported }: ImportPatientsModalProps) {
  const fileInputRef = useRef<HTMLInputElement | null>(null)
  const [selectedFile, setSelectedFile] = useState<File | null>(null)
  const [isDragging, setIsDragging] = useState(false)
  const [result, setResult] = useState<PatientsImportResponse | null>(null)

  const importMutation = useMutation({
    mutationFn: importPatients,
    onSuccess: (response) => {
      setResult(response)
      if (response.imported > 0) {
        toast.success('Importação concluída com sucesso.')
        onImported?.(response)
      } else {
        toast.success('Importação processada.')
      }
    },
    onError: (error) => {
      if (isAxiosError(error)) {
        const detail = error.response?.data?.detail
        if (typeof detail === 'string' && detail.trim()) {
          toast.error(detail)
          return
        }
      }
      toast.error('Não foi possível importar a planilha.')
    },
  })

  const hasResult = result !== null
  const resultCardClass = useMemo(() => {
    if (!result) return ''
    return result.imported > 0 ? 'border-emerald-200 bg-emerald-50' : 'border-slate-200 bg-slate-50'
  }, [result])

  const resetState = () => {
    setSelectedFile(null)
    setResult(null)
    setIsDragging(false)
    importMutation.reset()
    if (fileInputRef.current) {
      fileInputRef.current.value = ''
    }
  }

  const handleClose = () => {
    resetState()
    onClose()
  }

  const handleTemplateDownload = () => {
    const blob = new Blob([TEMPLATE_CONTENT], { type: 'text/csv;charset=utf-8;' })
    const url = window.URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = TEMPLATE_FILENAME
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    window.URL.revokeObjectURL(url)
  }

  const handleFileSelection = (file: File | null) => {
    setSelectedFile(file)
    setResult(null)
    importMutation.reset()
  }

  const handleDrop: DragEventHandler<HTMLDivElement> = (event) => {
    event.preventDefault()
    setIsDragging(false)
    const file = event.dataTransfer.files?.[0]
    handleFileSelection(file || null)
  }

  const handleProcessImport = () => {
    if (!selectedFile) {
      toast.error('Selecione um arquivo para continuar.')
      return
    }
    importMutation.mutate(selectedFile)
  }

  return (
    <Modal
      isOpen={isOpen}
      onClose={handleClose}
      title="Importar Pacientes em Massa"
      className="max-w-2xl"
    >
      <div className="space-y-4">
        <div className="rounded-lg border border-sky-200 bg-sky-50 px-4 py-3 text-sm text-sky-900">
          A planilha deve conter obrigatoriamente as colunas: nome, email e telefone. Formatos aceitos:
          CSV e XLSX. Baixe o modelo de exemplo abaixo.
        </div>

        <Button type="button" variant="secondary" onClick={handleTemplateDownload}>
          <Download className="h-4 w-4" />
          Baixar modelo CSV
        </Button>

        <div
          role="button"
          tabIndex={0}
          onClick={() => fileInputRef.current?.click()}
          onKeyDown={(event) => {
            if (event.key === 'Enter' || event.key === ' ') {
              event.preventDefault()
              fileInputRef.current?.click()
            }
          }}
          onDragOver={(event) => {
            event.preventDefault()
            setIsDragging(true)
          }}
          onDragLeave={() => setIsDragging(false)}
          onDrop={handleDrop}
          className={`rounded-lg border-2 border-dashed p-5 text-center transition ${
            isDragging
              ? 'border-primary bg-primary/5'
              : 'border-slate-300 bg-slate-50 hover:border-primary/60 hover:bg-primary/5'
          }`}
        >
          <input
            ref={fileInputRef}
            type="file"
            className="hidden"
            accept=".csv,.xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,text/csv"
            onChange={(event) => handleFileSelection(event.target.files?.[0] || null)}
          />
          <FileSpreadsheet className="mx-auto h-7 w-7 text-primary" />
          <p className="mt-2 text-sm font-medium text-night">Arraste e solte aqui ou clique para selecionar</p>
          <p className="caption mt-1">Formatos aceitos: .csv e .xlsx</p>
          {selectedFile ? (
            <p className="mt-3 rounded-md bg-white px-3 py-2 text-sm text-slate-700">
              Arquivo selecionado: <span className="font-semibold">{selectedFile.name}</span>
            </p>
          ) : null}
        </div>

        <Button
          type="button"
          onClick={handleProcessImport}
          disabled={!selectedFile || importMutation.isPending}
        >
          {importMutation.isPending ? (
            <>
              <Loader2 className="h-4 w-4 animate-spin" />
              Importando pacientes....
            </>
          ) : (
            <>
              <Upload className="h-4 w-4" />
              Processar Importacao
            </>
          )}
        </Button>

        {result ? (
          <div className={`rounded-lg border p-4 text-sm ${resultCardClass}`}>
            <p className="font-semibold text-night">{result.imported} pacientes importados com sucesso</p>
            <p className="mt-1 text-slate-700">{result.duplicates} duplicatas ignoradas</p>
            <p className="mt-1 text-slate-700">{result.errors} linhas com erro</p>
            {result.error_details?.length ? (
              <details className="mt-3 rounded-lg border border-slate-200 bg-white p-3">
                <summary className="cursor-pointer text-sm font-semibold text-night">
                  Ver detalhes dos erros
                </summary>
                <ul className="mt-2 list-disc space-y-1 pl-5 text-xs text-slate-600">
                  {result.error_details.map((detail) => (
                    <li key={detail}>{detail}</li>
                  ))}
                </ul>
              </details>
            ) : null}
          </div>
        ) : null}

        <div className="flex flex-wrap justify-end gap-2 pt-1">
          {hasResult ? (
            <Button type="button" variant="secondary" onClick={resetState}>
              Importar outra planilha
            </Button>
          ) : null}
          <Button type="button" variant="secondary" onClick={handleClose}>
            Fechar
          </Button>
        </div>
      </div>
    </Modal>
  )
}
