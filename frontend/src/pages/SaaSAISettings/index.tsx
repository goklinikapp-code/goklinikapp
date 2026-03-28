import { useMutation, useQuery } from "@tanstack/react-query";
import { useEffect, useState } from "react";
import toast from "react-hot-toast";
import { Eye, EyeOff } from "lucide-react";

import { getSaaSAISettings, updateSaaSAISettings } from "@/api/saas";
import { SectionHeader } from "@/components/shared/SectionHeader";
import { Button } from "@/components/ui/Button";
import { Card } from "@/components/ui/Card";
import { Input } from "@/components/ui/Input";

export default function SaaSAISettingsPage() {
  const { data, isLoading, refetch } = useQuery({
    queryKey: ["saas-ai-settings"],
    queryFn: getSaaSAISettings,
  });

  const [apiKey, setApiKey] = useState("");
  const [showApiKey, setShowApiKey] = useState(false);

  useEffect(() => {
    if (!data) return;
    setApiKey("");
  }, [data]);

  const mutation = useMutation({
    mutationFn: updateSaaSAISettings,
    onSuccess: () => {
      toast.success("Configuração de IA salva com sucesso");
      void refetch();
      setApiKey("");
    },
    onError: () => {
      toast.error("Não foi possível salvar a configuração de IA");
    },
  });

  if (isLoading || !data) {
    return <p className="body-copy">Carregando configurações de IA...</p>;
  }

  return (
    <div className="space-y-5">
      <SectionHeader
        title="Configurações de IA (SaaS)"
        subtitle="Defina somente a chave API da Grok. Provider, modelo e endpoint permanecem fixos no sistema."
      />

      <Card>
        <div className="grid gap-4">
          <div>
            <p className="mb-1 text-xs font-semibold text-slate-600">
              Chave API da Grok
            </p>
            <div className="relative">
              <Input
                type={showApiKey ? "text" : "password"}
                value={apiKey}
                className="pr-10"
                placeholder={
                  data.has_api_key
                    ? `Atual: ${data.api_key_masked}`
                    : "Cole a chave da Grok"
                }
                onChange={(event) => setApiKey(event.target.value)}
              />
              <button
                type="button"
                className="absolute right-2 top-2 rounded-md p-1 text-slate-500 hover:bg-slate-100"
                onClick={() => setShowApiKey((prev) => !prev)}
                aria-label={
                  showApiKey ? "Ocultar chave da API" : "Mostrar chave da API"
                }
              >
                {showApiKey ? (
                  <EyeOff className="h-4 w-4" />
                ) : (
                  <Eye className="h-4 w-4" />
                )}
              </button>
            </div>
            <p className="caption mt-1">
              Fonte atual:{" "}
              {data.key_source === "env"
                ? "arquivo .env (padrão do servidor)"
                : "painel SaaS"}
              .
            </p>
            <p className="caption mt-1">
              Ao salvar, o sistema passa a usar imediatamente a nova chave para
              as respostas da clínica.
            </p>
          </div>
        </div>

        <div className="mt-4 flex justify-end gap-2">
          <Button
            type="button"
            variant="secondary"
            onClick={() => setApiKey("")}
          >
            Descartar
          </Button>
          <Button
            type="button"
            onClick={() => mutation.mutate({ api_key: apiKey })}
            disabled={mutation.isPending}
          >
            {mutation.isPending ? "Salvando..." : "Salvar configuração"}
          </Button>
        </div>
      </Card>
    </div>
  );
}
