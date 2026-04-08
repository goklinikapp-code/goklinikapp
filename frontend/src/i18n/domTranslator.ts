import type { SupportedLanguage } from '@/i18n/system'

type Translations = Record<SupportedLanguage, string>

type Entry = {
  phrases: string[]
  translations: Translations
}

const ATTRIBUTES_TO_TRANSLATE = ['placeholder', 'title', 'aria-label'] as const

const entries: Entry[] = [
  makeEntry('Acessar Painel', 'Access Panel', 'Acceder al Panel', 'Zum Panel', 'Dostup k paneli', 'Panele Giris'),
  makeEntry(
    'Entre com suas credenciais de administrador.',
    'Sign in with your admin credentials.',
    'Inicia sesion con tus credenciales de administrador.',
    'Melden Sie sich mit Ihren Admin-Zugangsdaten an.',
    'Voydite s uchetnymi dannymi administratora.',
    'Yonetici kimlik bilgilerinizle giris yapin.',
  ),
  makeEntry('Email ou Número Fiscal', 'Email or Tax ID', 'Email o Numero Fiscal', 'E-Mail oder Steuernummer', 'Email ili nalogovyy nomer', 'E-posta veya Vergi Numarasi'),
  makeEntry('Senha', 'Password', 'Contrasena', 'Passwort', 'Parol', 'Sifre'),
  makeEntry('Digite sua senha', 'Enter your password', 'Ingresa tu contrasena', 'Passwort eingeben', 'Vvedite parol', 'Sifrenizi girin'),
  makeEntry('Esqueci minha senha', 'I forgot my password', 'Olvide mi contrasena', 'Passwort vergessen', 'Zabyl parol', 'Sifremi unuttum'),
  makeEntry('Entrando...', 'Signing in...', 'Iniciando sesion...', 'Anmeldung...', 'Vkhod...', 'Giris yapiliyor...'),
  makeEntry('Entrar', 'Sign in', 'Iniciar sesion', 'Anmelden', 'Voyti', 'Giris Yap'),
  makeEntry('ou continue com', 'or continue with', 'o continua con', 'oder fortfahren mit', 'ili prodolzhit s', 'veya sununla devam et'),
  makeEntry('Ainda não tem conta?', "Don't have an account yet?", 'Todavia no tienes cuenta?', 'Noch kein Konto?', 'Eshche net akkaunta?', 'Henuz hesabin yok mu?'),
  makeEntry('Cadastre-se', 'Sign up', 'Registrate', 'Registrieren', 'Registraciya', 'Kayit Ol'),
  makeEntry('Suporte', 'Support', 'Soporte', 'Support', 'Podderzhka', 'Destek'),
  makeEntry('Seguro', 'Secure', 'Seguro', 'Sicher', 'Bezopasno', 'Guvenli'),
  makeEntry('Protegido', 'Protected', 'Protegido', 'Gesichert', 'Zashchishcheno', 'Korumali'),

  makeEntry('Agenda', 'Schedule', 'Agenda', 'Terminplan', 'Raspisanie', 'Takvim'),
  makeEntry(
    'Visualize e gerencie os próximos atendimentos da clínica.',
    'View and manage upcoming clinic appointments.',
    'Visualiza y gestiona las proximas citas de la clinica.',
    'Zeigen und verwalten Sie die kommenden Termine der Klinik.',
    'Prosmatrivayte i upravlyayte blizhayshimi priemami kliniki.',
    'Klinigin yaklasan randevularini goruntuleyin ve yonetin.',
  ),
  makeEntry('Novo Agendamento', 'New Appointment', 'Nueva Cita', 'Neuer Termin', 'Novaya zapis', 'Yeni Randevu'),
  makeEntry('Carregando agendamentos...', 'Loading appointments...', 'Cargando citas...', 'Termine werden geladen...', 'Zagruzka zapisey...', 'Randevular yukleniyor...'),
  makeEntry('Sala Principal', 'Main Room', 'Sala Principal', 'Hauptraum', 'Glavnyy kabinet', 'Ana Oda'),
  makeEntry(
    'Nenhum agendamento encontrado nos próximos 365 dias.',
    'No appointments found in the next 365 days.',
    'No se encontraron citas en los proximos 365 dias.',
    'Keine Termine in den naechsten 365 Tagen gefunden.',
    'Na blizhayshie 365 dney zapisey ne naydeno.',
    'Sonraki 365 gunde randevu bulunamadi.',
  ),
  makeEntry('Novo Agendamento', 'New Appointment', 'Nueva Cita', 'Neuer Termin', 'Novaya zapis', 'Yeni Randevu'),
  makeEntry('Selecione o paciente', 'Select the patient', 'Selecciona el paciente', 'Patient auswaehlen', 'Vyberite pacienta', 'Hastayi secin'),
  makeEntry('Selecione o profissional', 'Select the professional', 'Selecciona el profesional', 'Fachkraft auswaehlen', 'Vyberite spetsialista', 'Uzmani secin'),
  makeEntry('Primeira Consulta', 'First Visit', 'Primera Consulta', 'Erstberatung', 'Pervichnaya konsultaciya', 'Ilk Muayene'),
  makeEntry('Retorno', 'Return Visit', 'Control', 'Folgetermin', 'Povtornyy priem', 'Kontrol'),
  makeEntry('Cirurgia', 'Surgery', 'Cirugia', 'Operation', 'Operaciya', 'Ameliyat'),
  makeEntry('Pós-op 7 dias', 'Post-op 7 days', 'Post-op 7 dias', 'Post-op 7 Tage', 'Posleoperatsionno 7 dney', 'Ameliyat sonrasi 7 gun'),
  makeEntry('Pós-op 30 dias', 'Post-op 30 days', 'Post-op 30 dias', 'Post-op 30 Tage', 'Posleoperatsionno 30 dney', 'Ameliyat sonrasi 30 gun'),
  makeEntry('Pós-op 90 dias', 'Post-op 90 days', 'Post-op 90 dias', 'Post-op 90 Tage', 'Posleoperatsionno 90 dney', 'Ameliyat sonrasi 90 gun'),
  makeEntry('Pós-op 7d', 'Post-op 7d', 'Post-op 7d', 'Post-op 7T', 'Posleoperatsionno 7d', 'Ameliyat sonrasi 7g'),
  makeEntry('Pós-op 30d', 'Post-op 30d', 'Post-op 30d', 'Post-op 30T', 'Posleoperatsionno 30d', 'Ameliyat sonrasi 30g'),
  makeEntry('Pós-op 90d', 'Post-op 90d', 'Post-op 90d', 'Post-op 90T', 'Posleoperatsionno 90d', 'Ameliyat sonrasi 90g'),
  makeEntry('Observações (opcional)', 'Notes (optional)', 'Observaciones (opcional)', 'Notizen (optional)', 'Primechaniya (neobyazatelno)', 'Notlar (istege bagli)'),
  makeEntry('Cancelar', 'Cancel', 'Cancelar', 'Abbrechen', 'Otmena', 'Iptal'),
  makeEntry('Salvar Agendamento', 'Save Appointment', 'Guardar Cita', 'Termin speichern', 'Sohranit zapis', 'Randevuyu Kaydet'),
  makeEntry('Salvando...', 'Saving...', 'Guardando...', 'Speichert...', 'Sohranenie...', 'Kaydediliyor...'),

  makeEntry('Configurações do Aplicativo', 'App Settings', 'Configuracion de la App', 'App-Einstellungen', 'Nastroyki prilozheniya', 'Uygulama Ayarlari'),
  makeEntry(
    'Personalize a experiência do paciente no ambiente white-label da clínica.',
    'Customize the patient experience in the clinic white-label environment.',
    'Personaliza la experiencia del paciente en el entorno white-label de la clinica.',
    'Passen Sie das Patientenerlebnis im White-Label-Umfeld der Klinik an.',
    'Nastroyte opyt pacienta v white-label srede kliniki.',
    'Klinigin white-label ortaminda hasta deneyimini ozellestirin.',
  ),
  makeEntry('Identidade Visual', 'Visual Identity', 'Identidad Visual', 'Visuelle Identitaet', 'Vizualnaya identichnost', 'Gorsel Kimlik'),
  makeEntry('Especialidades', 'Specialties', 'Especialidades', 'Fachgebiete', 'Spetsialnosti', 'Uzmanliklar'),
  makeEntry('Profissionais', 'Professionals', 'Profesionales', 'Fachkraefte', 'Spetsialisty', 'Uzmanlar'),
  makeEntry('Conteúdo', 'Content', 'Contenido', 'Inhalt', 'Kontent', 'Icerik'),
  makeEntry('Paleta de Cores', 'Color Palette', 'Paleta de Colores', 'Farbpalette', 'Palitra tsvetov', 'Renk Paleti'),
  makeEntry(
    'As três cores padrão já vêm com a identidade principal da plataforma.',
    'The three default colors already match the platform identity.',
    'Los tres colores predeterminados ya siguen la identidad de la plataforma.',
    'Die drei Standardfarben entsprechen bereits der Plattformidentitaet.',
    'Tri standartnykh tsveta uzhe sootvetstvuyut firmennomu stilyu platformy.',
    'Uc varsayilan renk zaten platform kimligine uygundur.',
  ),
  makeEntry('Paleta padrão do SaaS', 'SaaS default palette', 'Paleta predeterminada SaaS', 'SaaS-Standardpalette', 'Standartnaya palitra SaaS', 'SaaS varsayilan paleti'),
  makeEntry('Cor Primária', 'Primary Color', 'Color Primario', 'Primaerfarbe', 'Osnovnoy tsvet', 'Birincil Renk'),
  makeEntry(
    'Usada em cabeçalhos e botões principais',
    'Used in headers and primary buttons',
    'Usado en encabezados y botones principales',
    'Wird in Kopfzeilen und Hauptbuttons verwendet',
    'Ispolzuetsya v zagolovkakh i osnovnykh knopkakh',
    'Basliklarda ve ana butonlarda kullanilir',
  ),
  makeEntry('Cor Secundária', 'Secondary Color', 'Color Secundario', 'Sekundaerfarbe', 'Vtorichnyy tsvet', 'Ikincil Renk'),
  makeEntry(
    'Elementos de apoio e badges',
    'Supporting elements and badges',
    'Elementos de apoyo e insignias',
    'Unterstuetzende Elemente und Badges',
    'Vspomogatelnye elementy i bedzhi',
    'Destekleyici ogeler ve rozetler',
  ),
  makeEntry('Cor de Destaque', 'Accent Color', 'Color de Destaque', 'Akzentfarbe', 'Aktsentnyy tsvet', 'Vurgu Rengi'),
  makeEntry(
    'Call-to-actions e alertas',
    'Call-to-actions and alerts',
    'Llamadas a la accion y alertas',
    'Call-to-Actions und Warnungen',
    'Prizyvy k deystviyu i preduprezhdeniya',
    'Harekete gecirici butonlar ve uyarilar',
  ),
  makeEntry('Usar paleta SaaS', 'Use SaaS palette', 'Usar paleta SaaS', 'SaaS-Palette verwenden', 'Ispolzovat palitru SaaS', 'SaaS paletini kullan'),
  makeEntry('Idioma e Moeda do Painel', 'Panel Language and Currency', 'Idioma y Moneda del Panel', 'Sprache und Waehrung des Panels', 'Yazyk i valuta paneli', 'Panel Dil ve Para Birimi'),
  makeEntry(
    'Por padrão o sistema detecta o idioma do navegador. Você pode sobrescrever manualmente abaixo.',
    'By default, the system detects the browser language. You can manually override it below.',
    'Por defecto, el sistema detecta el idioma del navegador. Puedes sobrescribirlo manualmente abajo.',
    'Standardmaessig erkennt das System die Browsersprache. Sie koennen sie unten manuell ueberschreiben.',
    'Po umolchaniyu sistema opredelyaet yazyk brauzera. Vy mozhete vruchnuyu pereopredelit ego nizhe.',
    'Varsayilan olarak sistem tarayici dilini algilar. Asagidan manuel olarak degistirebilirsiniz.',
  ),
  makeEntry('Idioma', 'Language', 'Idioma', 'Sprache', 'Yazyk', 'Dil'),
  makeEntry('Moeda', 'Currency', 'Moneda', 'Waehrung', 'Valyuta', 'Para birimi'),
  makeEntry('Reaplicar moeda automática por idioma', 'Reapply automatic currency by language', 'Reaplicar moneda automatica por idioma', 'Automatische Waehrung nach Sprache erneut anwenden', 'Povtorno primenit avtomaticheskuyu valyutu po yazyku', 'Dile gore otomatik para birimini yeniden uygula'),
  makeEntry('Logo da Clínica', 'Clinic Logo', 'Logo de la Clinica', 'Kliniklogo', 'Logotip kliniki', 'Klinik Logosu'),
  makeEntry('Arraste PNG/SVG ou clique para upload', 'Drag PNG/SVG or click to upload', 'Arrastra PNG/SVG o haz clic para subir', 'PNG/SVG ziehen oder zum Hochladen klicken', 'Peretashchite PNG/SVG ili nazhmite dlya zagruzki', 'PNG/SVG surukleyin veya yuklemek icin tiklayin'),
  makeEntry('Recomendado: 512x512px', 'Recommended: 512x512px', 'Recomendado: 512x512px', 'Empfohlen: 512x512px', 'Rekomenduetsya: 512x512px', 'Onerilen: 512x512px'),
  makeEntry('URL pública da logo', 'Public logo URL', 'URL publica del logo', 'Oeffentliche Logo-URL', 'Publichnyy URL logotipa', 'Logo acik URL'),
  makeEntry('Preview do novo logo', 'New logo preview', 'Vista previa del nuevo logo', 'Vorschau des neuen Logos', 'Predprosmotr novogo logotipa', 'Yeni logo onizleme'),
  makeEntry('Preview app do paciente', 'Patient app preview', 'Vista previa app del paciente', 'Patienten-App-Vorschau', 'Predprosmotr prilozheniya pacienta', 'Hasta uygulama onizlemesi'),
  makeEntry('Próxima consulta', 'Next appointment', 'Proxima consulta', 'Naechster Termin', 'Sleduyushchiy priem', 'Sonraki randevu'),
  makeEntry('Checklist Pós-op', 'Post-op Checklist', 'Checklist Post-op', 'Post-op Checkliste', 'Chek-list posle operatsii', 'Ameliyat Sonrasi Kontrol Listesi'),
  makeEntry('Bem-vinda, Aylin', 'Welcome, Aylin', 'Bienvenida, Aylin', 'Willkommen, Aylin', 'Dobro pozhalovat, Aylin', 'Hos geldin, Aylin'),
  makeEntry('Descartar', 'Discard', 'Descartar', 'Verwerfen', 'Otmenit', 'Vazgec'),
  makeEntry('Salvar Alterações', 'Save Changes', 'Guardar Cambios', 'Aenderungen speichern', 'Sohranit izmeneniya', 'Degisiklikleri Kaydet'),
  makeEntry('Configurações salvas com sucesso', 'Settings saved successfully', 'Configuraciones guardadas con exito', 'Einstellungen erfolgreich gespeichert', 'Nastroyki uspeshno sokhraneny', 'Ayarlar basariyla kaydedildi'),
  makeEntry('Não foi possível salvar as configurações no backend', 'Could not save settings in backend', 'No fue posible guardar la configuracion en el backend', 'Einstellungen konnten im Backend nicht gespeichert werden', 'Ne udalos sohranit nastroyki v backend', 'Ayarlar backendde kaydedilemedi'),
  makeEntry('VISÍVEL', 'VISIBLE', 'VISIBLE', 'SICHTBAR', 'VIDIMO', 'GORUNUR'),
  makeEntry('OCULTO', 'HIDDEN', 'OCULTO', 'VERBORGEN', 'SKRYT', 'GIZLI'),
  makeEntry('Conteúdo do App', 'App Content', 'Contenido de la App', 'App-Inhalt', 'Kontent prilozheniya', 'Uygulama Icerigi'),
  makeEntry(
    'Módulo preparado para configurar protocolos, textos de onboarding e campanhas no app do paciente.',
    'Module prepared to configure protocols, onboarding texts and campaigns in the patient app.',
    'Modulo preparado para configurar protocolos, textos de onboarding y campanas en la app del paciente.',
    'Modul zur Konfiguration von Protokollen, Onboarding-Texten und Kampagnen in der Patienten-App.',
    'Modul podgotovlen dlya nastroyki protokolov, onboarding-tekstov i kampaniy v prilozhenii pacienta.',
    'Hasta uygulamasinda protokoller, onboarding metinleri ve kampanyalari ayarlamak icin hazir moduldur.',
  ),
  makeEntry(
    'Aqui você poderá definir banners, mensagens de boas-vindas e conteúdo educativo por especialidade.',
    'Here you can define banners, welcome messages and educational content by specialty.',
    'Aqui podras definir banners, mensajes de bienvenida y contenido educativo por especialidad.',
    'Hier koennen Sie Banner, Begruessungsnachrichten und Bildungsinhalte nach Fachgebiet definieren.',
    'Zdes vy smozhete opredelit bannery, privetstvennye soobshcheniya i obrazovatelnyy kontent po spetsialnosti.',
    'Burada uzmanliga gore bannerlari, hos geldiniz mesajlarini ve egitici icerigi tanimlayabilirsiniz.',
  ),
  makeEntry('Editar Conteúdo', 'Edit Content', 'Editar Contenido', 'Inhalt bearbeiten', 'Redaktirovat kontent', 'Icerigi Duzenle'),
  makeEntry(
    'Editor de conteúdo avançado será disponibilizado em breve.',
    'Advanced content editor will be available soon.',
    'El editor de contenido avanzado estara disponible pronto.',
    'Der erweiterte Inhaltseditor wird bald verfuegbar sein.',
    'Rasshirennyy redaktor kontenta skoro budet dostupen.',
    'Gelismis icerik duzenleyicisi yakinda kullanima sunulacak.',
  ),

  makeEntry('Pacientes', 'Patients', 'Pacientes', 'Patienten', 'Pacienty', 'Hastalar'),
  makeEntry('Gestão de Pacientes', 'Patient Management', 'Gestion de Pacientes', 'Patientenverwaltung', 'Upravlenie pacientami', 'Hasta Yonetimi'),
  makeEntry('Todas Especialidades', 'All Specialties', 'Todas las Especialidades', 'Alle Fachgebiete', 'Vse spetsialnosti', 'Tum Uzmanliklar'),
  makeEntry('Todos Status', 'All Status', 'Todos los Estados', 'Alle Status', 'Vse statusy', 'Tum Durumlar'),
  makeEntry('Mais Filtros', 'More Filters', 'Mas Filtros', 'Mehr Filter', 'Bolshe filtrov', 'Daha Fazla Filtre'),
  makeEntry('PACIENTE', 'PATIENT', 'PACIENTE', 'PATIENT', 'PACIENT', 'HASTA'),
  makeEntry('CONTATO', 'CONTACT', 'CONTACTO', 'KONTAKT', 'KONTAKT', 'ILETISIM'),
  makeEntry('ÚLTIMA VISITA', 'LAST VISIT', 'ULTIMA VISITA', 'LETZTER BESUCH', 'POSLEDNIY VIZIT', 'SON ZIYARET'),
  makeEntry('ESPECIALIDADE', 'SPECIALTY', 'ESPECIALIDAD', 'FACHGEBIET', 'SPETSIALNOST', 'UZMANLIK'),
  makeEntry('Novo Paciente', 'New Patient', 'Nuevo Paciente', 'Neuer Patient', 'Novyy pacient', 'Yeni Hasta'),
  makeEntry('Carregando pacientes...', 'Loading patients...', 'Cargando pacientes...', 'Patienten werden geladen...', 'Zagruzka pacientov...', 'Hastalar yukleniyor...'),
  makeEntry('Nenhum paciente encontrado com os filtros atuais.', 'No patients found with current filters.', 'No se encontraron pacientes con los filtros actuales.', 'Keine Patienten mit den aktuellen Filtern gefunden.', 'Po tekushchim filtram pacienty ne naydeny.', 'Mevcut filtrelerle hasta bulunamadi.'),
  makeEntry('Informações de Contato', 'Contact Information', 'Informacion de Contacto', 'Kontaktinformationen', 'Kontaktnaya informaciya', 'Iletisim Bilgileri'),
  makeEntry('Histórico Clínico', 'Clinical History', 'Historial Clinico', 'Klinische Historie', 'Klinicheskaya istoriya', 'Klinik Gecmis'),
  makeEntry('Médico Responsável', 'Responsible Doctor', 'Medico Responsable', 'Zustaendiger Arzt', 'Otvetstvennyy vrach', 'Sorumlu Doktor'),
  makeEntry('Sem médico designado', 'No assigned doctor', 'Sin medico asignado', 'Kein zugewiesener Arzt', 'Vrach ne naznachen', 'Atanmis doktor yok'),
  makeEntry('Direcionar para Médico', 'Assign to Doctor', 'Asignar al Medico', 'Dem Arzt zuweisen', 'Naznachit vrachu', 'Doktora Yonlendir'),
  makeEntry('Visita registrada', 'Recorded visit', 'Visita registrada', 'Registrierter Besuch', 'Zafiksirovannyy vizit', 'Kayitli ziyaret'),
  makeEntry('Último procedimento:', 'Last procedure:', 'Ultimo procedimiento:', 'Letztes Verfahren:', 'Poslednyaya protsedura:', 'Son islem:'),
  makeEntry('Não informado', 'Not informed', 'No informado', 'Nicht angegeben', 'Ne ukazano', 'Belirtilmedi'),
  makeEntry('Ver Perfil Completo', 'View Full Profile', 'Ver Perfil Completo', 'Vollstaendiges Profil anzeigen', 'Posmotret polnyy profil', 'Tum Profili Goruntule'),
  makeEntry('Editar', 'Edit', 'Editar', 'Bearbeiten', 'Redaktirovat', 'Duzenle'),
  makeEntry('Financeiro', 'Billing', 'Facturacion', 'Abrechnung', 'Billing', 'Faturalama'),
  makeEntry('Direcionar Paciente para Médico', 'Assign Patient to Doctor', 'Asignar Paciente al Medico', 'Patient dem Arzt zuweisen', 'Napravit pacienta k vrachu', 'Hastayi Doktora Yonlendir'),
  makeEntry('Selecionar Médico', 'Select Doctor', 'Seleccionar Medico', 'Arzt auswaehlen', 'Vybrat vracha', 'Doktor Sec'),
  makeEntry('Selecione um médico', 'Select a doctor', 'Seleccione un medico', 'Arzt auswaehlen', 'Vyberite vracha', 'Bir doktor secin'),
  makeEntry('Observações', 'Notes', 'Observaciones', 'Notizen', 'Zametki', 'Notlar'),
  makeEntry('Instruções adicionais para o médico', 'Additional instructions for the doctor', 'Instrucciones adicionales para el medico', 'Zusaetzliche Hinweise fuer den Arzt', 'Dopolnitelnye instruktsii dlya vracha', 'Doktor icin ek talimatlar'),
  makeEntry('Itens por pagina:', 'Items per page:', 'Elementos por pagina:', 'Elemente pro Seite:', 'Elementov na stranitse:', 'Sayfa basina oge:'),
  makeEntry('Itens por página:', 'Items per page:', 'Elementos por pagina:', 'Elemente pro Seite:', 'Elementov na stranitse:', 'Sayfa basina oge:'),
  makeEntry('Anterior', 'Previous', 'Anterior', 'Zurueck', 'Nazad', 'Onceki'),
  makeEntry('Próxima', 'Next', 'Siguiente', 'Weiter', 'Dalee', 'Sonraki'),
  makeEntry('Nome Completo', 'Full Name', 'Nombre Completo', 'Vollstaendiger Name', 'Polnoe imya', 'Tam Ad'),
  makeEntry('Número Fiscal', 'Tax Number', 'Numero Fiscal', 'Steuernummer', 'Nalogovyy nomer', 'Vergi Numarasi'),
  makeEntry('Telefone', 'Phone', 'Telefono', 'Telefon', 'Telefon', 'Telefon'),
  makeEntry('Senha temporária', 'Temporary password', 'Contrasena temporal', 'Temporäres Passwort', 'Vremennyy parol', 'Gecici sifre'),
  makeEntry('Especialidade de interesse', 'Specialty of interest', 'Especialidad de interes', 'Interessensfachgebiet', 'Interesuyushchaya spetsialnost', 'Ilgilendigini̇z uzmanlik'),
  makeEntry('Salvar Paciente', 'Save Patient', 'Guardar Paciente', 'Patient speichern', 'Sohranit pacienta', 'Hastayi Kaydet'),
  makeEntry('Paciente criado com sucesso', 'Patient created successfully', 'Paciente creado con exito', 'Patient erfolgreich erstellt', 'Pacient uspeshno sozdan', 'Hasta basariyla olusturuldu'),

  makeEntry('Equipe da Clínica', 'Clinic Team', 'Equipo de la Clinica', 'Klinikteam', 'Komanda kliniki', 'Klinik Ekibi'),
  makeEntry('Convidar Usuário', 'Invite User', 'Invitar Usuario', 'Benutzer einladen', 'Priglasit polzovatelya', 'Kullanici Davet Et'),
  makeEntry('Membros da Equipe', 'Team Members', 'Miembros del Equipo', 'Teammitglieder', 'Chleny komandy', 'Ekip Uyeleri'),
  makeEntry('Log de Atividades Recentes', 'Recent Activity Log', 'Registro de Actividad Reciente', 'Aktivitaetsprotokoll', 'Zhurnal poslednih deystviy', 'Son Etkinlik Gunlugu'),
  makeEntry('Convidar Novo Usuário', 'Invite New User', 'Invitar Nuevo Usuario', 'Neuen Benutzer einladen', 'Priglasit novogo polzovatelya', 'Yeni Kullanici Davet Et'),
  makeEntry('Nome Completo', 'Full Name', 'Nombre Completo', 'Vollstaendiger Name', 'Polnoe imya', 'Tam Ad'),
  makeEntry('E-mail Corporativo', 'Corporate Email', 'Correo Corporativo', 'Geschaeftliche E-Mail', 'Korporativnaya pochta', 'Kurumsal E-posta'),
  makeEntry('Perfil de Acesso', 'Access Profile', 'Perfil de Acceso', 'Zugriffsprofil', 'Profil dostupa', 'Erisim Profili'),
  makeEntry('Disparar Convite', 'Send Invite', 'Enviar Invitacion', 'Einladung senden', 'Otpravit priglashenie', 'Davet Gonder'),
  makeEntry('Enviando...', 'Sending...', 'Enviando...', 'Wird gesendet...', 'Otpravka...', 'Gonderiliyor...'),

  makeEntry('Dashboard', 'Dashboard', 'Panel', 'Dashboard', 'Panel', 'Panel'),
  makeEntry('Carregando dashboard...', 'Loading dashboard...', 'Cargando panel...', 'Dashboard wird geladen...', 'Zagruzka paneli...', 'Panel yukleniyor...'),
  makeEntry('Taxa de Ocupação', 'Occupancy Rate', 'Tasa de Ocupacion', 'Auslastungsrate', 'Uroven zagruzki', 'Doluluk Orani'),
  makeEntry('Capacidade otimizada', 'Optimized capacity', 'Capacidad optimizada', 'Optimierte Kapazitaet', 'Optimizirovannaya vmestimost', 'Optimize kapasite'),
  makeEntry('Evolução de Faturamento', 'Revenue Evolution', 'Evolucion de Ingresos', 'Umsatzentwicklung', 'Dinamika vyruchki', 'Gelir Gelisimi'),
  makeEntry('Carregando relatórios...', 'Loading reports...', 'Cargando informes...', 'Berichte werden geladen...', 'Zagruzka otchetov...', 'Raporlar yukleniyor...'),
  makeEntry('Não foi possível carregar os relatórios.', 'Could not load reports.', 'No fue posible cargar los informes.', 'Berichte konnten nicht geladen werden.', 'Ne udalos zagruzit otchety.', 'Raporlar yuklenemedi.'),
  makeEntry('Tentar novamente', 'Try again', 'Intentar de nuevo', 'Erneut versuchen', 'Poprobovat snova', 'Tekrar dene'),
  makeEntry('Sem dados de relatório para o período atual.', 'No report data for the current period.', 'No hay datos de informes para el periodo actual.', 'Keine Berichtsdaten fuer den aktuellen Zeitraum.', 'Net dannykh otchetov za tekushchiy period.', 'Mevcut donem icin rapor verisi yok.'),
  makeEntry('CLINIC MASTER', 'CLINIC MASTER', 'DUENO CLINICA', 'KLINIKLEITER', 'VLADLETS KLINIKI', 'KLINIK SAHIBI'),
  makeEntry('SURGEON', 'SURGEON', 'CIRUJANO', 'CHIRURG', 'KHIRURG', 'CERRAH'),
  makeEntry('SECRETARY', 'SECRETARY', 'SECRETARIA', 'SEKRETARIAT', 'SEKRETAR', 'SEKRETER'),
  makeEntry('NURSING', 'NURSING', 'ENFERMERIA', 'PFLEGE', 'MEDSESTRA', 'HEMSIRE'),
  makeEntry('ACTIVE', 'ACTIVE', 'ACTIVO', 'AKTIV', 'AKTIVEN', 'AKTIF'),
  makeEntry('INACTIVE', 'INACTIVE', 'INACTIVO', 'INAKTIV', 'NE AKTIVNO', 'PASIF'),
  makeEntry('Distribuição por Especialidade', 'Distribution by Specialty', 'Distribucion por Especialidad', 'Verteilung nach Fachgebiet', 'Raspredelenie po spetsialnosti', 'Uzmanliga Gore Dagilim'),
  makeEntry('Próximos Atendimentos', 'Upcoming Appointments', 'Proximas Citas', 'Kommende Termine', 'Blizhayshie priemy', 'Yaklasan Randevular'),
  makeEntry('Ver agenda completa', 'View full schedule', 'Ver agenda completa', 'Vollen Terminplan anzeigen', 'Posmotret vse raspisanie', 'Tum takvimi gor'),
  makeEntry('Alertas Inteligentes', 'Smart Alerts', 'Alertas Inteligentes', 'Intelligente Warnungen', 'Umnye preduprezhdeniya', 'Akilli Uyarilar'),
  makeEntry('INSIGHT DO DIA', 'INSIGHT OF THE DAY', 'IDEA DEL DIA', 'ERKENNTNIS DES TAGES', 'INSAYT DNYA', 'GUNUN ICGORUSU'),
  makeEntry('Ativar Campanha', 'Activate Campaign', 'Activar Campana', 'Kampagne aktivieren', 'Aktivirovat kampaniyu', 'Kampanyayi Etkinlestir'),

  makeEntry('Disparo em Massa', 'Mass Messaging', 'Envio Masivo', 'Massenversand', 'Massovaya rassylka', 'Toplu Gonderim'),
  makeEntry(
    'Gerencie campanhas, workflows e histórico de comunicação.',
    'Manage campaigns, workflows and communication history.',
    'Gestiona campanas, flujos y el historial de comunicacion.',
    'Verwalten Sie Kampagnen, Workflows und Kommunikationsverlauf.',
    'Upravlyayte kampaniyami, protsessami i istoriey kommunikatsiy.',
    'Kampanyalari, is akislarini ve iletisim gecmisini yonetin.',
  ),
  makeEntry('Segmento de Público', 'Audience Segment', 'Segmento de Publico', 'Zielgruppensegment', 'Segment auditorii', 'Hedef Kitle Segmenti'),
  makeEntry('Todos os pacientes', 'All patients', 'Todos los pacientes', 'Alle Patienten', 'Vse pacienty', 'Tum hastalar'),
  makeEntry(
    'Pacientes com +6 meses sem consulta',
    'Patients with +6 months without appointment',
    'Pacientes con +6 meses sin consulta',
    'Patienten mit +6 Monaten ohne Termin',
    'Pacienty bez priema bolee 6 mesyatsev',
    '6+ aydir randevusu olmayan hastalar',
  ),
  makeEntry('Por especialidade', 'By specialty', 'Por especialidad', 'Nach Fachgebiet', 'Po spetsialnosti', 'Uzmanliga gore'),
  makeEntry('Canal de Envio', 'Delivery Channel', 'Canal de Envio', 'Versandkanal', 'Kanal otpravki', 'Gonderim Kanali'),
  makeEntry('Variáveis', 'Variables', 'Variables', 'Variablen', 'Peremennye', 'Degiskenler'),
  makeEntry('Corpo da Mensagem', 'Message Body', 'Cuerpo del Mensaje', 'Nachrichtentext', 'Telo soobshcheniya', 'Mesaj Govdesi'),
  makeEntry('Selecione um segmento', 'Select a segment', 'Selecciona un segmento', 'Waehlen Sie ein Segment', 'Vyberite segment', 'Bir segment secin'),
  makeEntry('Mensagem muito curta', 'Message too short', 'Mensaje muy corto', 'Nachricht zu kurz', 'Soobshchenie slishkom korotkoe', 'Mesaj cok kisa'),
  makeEntry('caracteres', 'characters', 'caracteres', 'Zeichen', 'simvolov', 'karakter'),
  makeEntry('Créditos estimados:', 'Estimated credits:', 'Creditos estimados:', 'Geschaetzte Credits:', 'Predpologaemye kredity:', 'Tahmini krediler:'),
  makeEntry('Agendar Disparo', 'Schedule Broadcast', 'Programar Envio', 'Versand planen', 'Zaplaniruyte rassylku', 'Toplu gonderimi planla'),
  makeEntry('Pré-visualização', 'Preview', 'Vista previa', 'Vorschau', 'Predprosmotr', 'Onizleme'),
  makeEntry('Disparo enviado com sucesso', 'Broadcast sent successfully', 'Envio realizado con exito', 'Versand erfolgreich durchgefuehrt', 'Rassylka uspeshno otpravlena', 'Toplu gonderim basariyla gonderildi'),
  makeEntry('Falha ao enviar disparo', 'Failed to send broadcast', 'Error al enviar', 'Versand fehlgeschlagen', 'Ne udalos otpravit rassylku', 'Toplu gonderim basarisiz'),
  makeEntry(
    'Agendamento de disparo será disponibilizado em breve.',
    'Broadcast scheduling will be available soon.',
    'La programacion de envios estara disponible pronto.',
    'Die Versandplanung wird bald verfuegbar sein.',
    'Planirovanie rassylki skoro budet dostupno.',
    'Toplu gonderim planlama yakinda kullanima acilacak.',
  ),
  makeEntry(
    'Criação de workflow customizado em breve.',
    'Custom workflow creation coming soon.',
    'La creacion de workflows personalizados llegara pronto.',
    'Benutzerdefinierte Workflow-Erstellung in Kuerze.',
    'Sozdanie individualnykh protsessov skoro.',
    'Ozel is akisi olusturma yakinda.',
  ),
  makeEntry('Workflows Automatizados', 'Automated Workflows', 'Workflows Automatizados', 'Automatisierte Workflows', 'Avtomatizirovannye rabochie protsessy', 'Otomatik Is Akislari'),
  makeEntry('Novo Workflow', 'New Workflow', 'Nuevo Workflow', 'Neuer Workflow', 'Novyy workflow', 'Yeni Is Akisi'),
  makeEntry('Histórico de Envios', 'Send History', 'Historial de Envios', 'Sendeverlauf', 'Istoriya otpravok', 'Gonderim Gecmisi'),
  makeEntry('TRIGGER:', 'TRIGGER:', 'DISPARADOR:', 'AUSLOESER:', 'TRIGGER:', 'TETIKLEYICI:'),
  makeEntry('AÇÃO:', 'ACTION:', 'ACCION:', 'AKTION:', 'DEYSTVIE:', 'AKSIYON:'),
  makeEntry('Enviado', 'Sent', 'Enviado', 'Gesendet', 'Otpravleno', 'Gonderildi'),
  makeEntry('Erro', 'Error', 'Error', 'Fehler', 'Oshibka', 'Hata'),
  makeEntry('TAXA DE ABERTURA', 'OPEN RATE', 'TASA DE APERTURA', 'OEFFNUNGSRATE', 'PROCENT OTKRYTIYA', 'ACILMA ORANI'),
  makeEntry('AÇÕES', 'ACTIONS', 'ACCIONES', 'AKTIONEN', 'DEYSTVIYA', 'AKSIYONLAR'),
  makeEntry('1-10 de 42 envios', '1-10 of 42 sends', '1-10 de 42 envios', '1-10 von 42 Sendungen', '1-10 iz 42 otpravok', '42 gonderimden 1-10'),
  makeEntry('Lembrete de Consulta 24h antes', 'Appointment Reminder 24h before', 'Recordatorio de Consulta 24h antes', 'Termin-Erinnerung 24h vorher', 'Napominanie o prieme za 24 chasa', 'Randevu Hatirlatmasi 24 saat once'),
  makeEntry('TRIGGER: 24h antes do agendamento', 'TRIGGER: 24h before appointment', 'DISPARADOR: 24h antes de la cita', 'AUSLOESER: 24h vor dem Termin', 'TRIGGER: za 24 chasa do zapisi', 'TETIKLEYICI: Randevudan 24 saat once'),
  makeEntry('AÇÃO: Enviar push e WhatsApp', 'ACTION: Send push and WhatsApp', 'ACCION: Enviar push y WhatsApp', 'AKTION: Push und WhatsApp senden', 'DEYSTVIE: Otpra vit push i WhatsApp', 'AKSIYON: Push ve WhatsApp gonder'),
  makeEntry('Follow-up Pós-op D+7', 'Post-op Follow-up D+7', 'Seguimiento Post-op D+7', 'Post-op Nachverfolgung D+7', 'Posleoperatsionnyy follow-up D+7', 'Ameliyat Sonrasi Takip D+7'),
  makeEntry('TRIGGER: Ao completar 7 dias da cirurgia', 'TRIGGER: After 7 days from surgery', 'DISPARADOR: Al completar 7 dias de la cirugia', 'AUSLOESER: Nach 7 Tagen seit der OP', 'TRIGGER: Posle 7 dney s momenta operatsii', 'TETIKLEYICI: Ameliyattan 7 gun sonra'),
  makeEntry('AÇÃO: Enviar checklist e orientações', 'ACTION: Send checklist and guidance', 'ACCION: Enviar checklist y orientaciones', 'AKTION: Checkliste und Anweisungen senden', 'DEYSTVIE: Otpra vit chek-list i instruktsii', 'AKSIYON: Kontrol listesi ve yonlendirmeler gonder'),
  makeEntry('Reativação de Pacientes Inativos', 'Reactivation of Inactive Patients', 'Reactivacion de Pacientes Inactivos', 'Reaktivierung inaktiver Patienten', 'Reaktivatsiya neaktivnykh pacientov', 'Pasif Hastalarin Yeniden Etkinlestirilmesi'),
  makeEntry('Reativação de Patients Inativos', 'Reactivation of Inactive Patients', 'Reactivacion de Pacientes Inactivos', 'Reaktivierung inaktiver Patienten', 'Reaktivatsiya neaktivnykh pacientov', 'Pasif Hastalarin Yeniden Etkinlestirilmesi'),
  makeEntry('TRIGGER: Sem consulta há 180 dias', 'TRIGGER: No appointment for 180 days', 'DISPARADOR: Sin consulta hace 180 dias', 'AUSLOESER: Kein Termin seit 180 Tagen', 'TRIGGER: Bez priema 180 dney', 'TETIKLEYICI: 180 gundur randevu yok'),
  makeEntry('AÇÃO: Disparar campanha segmentada', 'ACTION: Trigger segmented campaign', 'ACCION: Disparar campana segmentada', 'AKTION: Segmentierte Kampagne ausloesen', 'DEYSTVIE: Zapustit segmentirovannuyu kampaniyu', 'AKSIYON: Segmentli kampanya baslat'),

  makeEntry('Planos de Viagem', 'Travel Plans', 'Planes de Viaje', 'Reiseplaene', 'Plany poezdki', 'Seyahat Planlari'),
  makeEntry(
    'Gerencie as informações logísticas dos pacientes internacionais.',
    'Manage international patients travel logistics.',
    'Gestiona la logistica de viaje de pacientes internacionales.',
    'Verwalten Sie die Reiselogistik internationaler Patienten.',
    'Upravlyayte logistikoĭ poezdok mezhdunarodnykh pacientov.',
    'Uluslararasi hastalarin seyahat lojistigini yonetin.',
  ),
  makeEntry('Novo Plano', 'New Plan', 'Nuevo Plan', 'Neuer Plan', 'Novyy plan', 'Yeni Plan'),
  makeEntry('DATA DE CHEGADA', 'ARRIVAL DATE', 'FECHA DE LLEGADA', 'ANREISEDATUM', 'DATA PRILETA', 'VARIS TARIHI'),
  makeEntry('HOTEL', 'HOTEL', 'HOTEL', 'HOTEL', 'OTEL', 'OTEL'),
  makeEntry('TRANSFERS', 'TRANSFERS', 'TRASLADOS', 'TRANSFERS', 'TRANSFERY', 'TRANSFERLER'),
  makeEntry('STATUS DO PRÓXIMO TRANSFER', 'NEXT TRANSFER STATUS', 'ESTADO DEL SIGUIENTE TRASLADO', 'STATUS DES NAECHSTEN TRANSFERS', 'STATUS SLEDUYUSHCHEGO TRANSFERA', 'SONRAKI TRANSFER DURUMU'),
  makeEntry('Carregando planos de viagem...', 'Loading travel plans...', 'Cargando planes de viaje...', 'Reiseplaene werden geladen...', 'Zagruzka planov poezdki...', 'Seyahat planlari yukleniyor...'),
  makeEntry('Não foi possível carregar os planos de viagem.', 'Could not load travel plans.', 'No fue posible cargar los planes de viaje.', 'Reiseplaene konnten nicht geladen werden.', 'Ne udalos zagruzit plany poezdki.', 'Seyahat planlari yuklenemedi.'),
  makeEntry('Ainda não existe nenhum plano de viagem cadastrado.', 'There are no registered travel plans yet.', 'Todavia no hay planes de viaje registrados.', 'Es sind noch keine Reiseplaene registriert.', 'Poka net zaregistrirovannykh planov poezdki.', 'Henuz kayitli seyahat plani yok.'),
  makeEntry('Editar Plano', 'Edit Plan', 'Editar Plan', 'Plan bearbeiten', 'Redaktirovat plan', 'Plani Duzenle'),
  makeEntry('Editar Plano de Viagem', 'Edit Travel Plan', 'Editar Plan de Viaje', 'Reiseplan bearbeiten', 'Redaktirovat plan poezdki', 'Seyahat Planini Duzenle'),
  makeEntry('Novo Plano de Viagem', 'New Travel Plan', 'Nuevo Plan de Viaje', 'Neuer Reiseplan', 'Novyy plan poezdki', 'Yeni Seyahat Plani'),
  makeEntry('Criando...', 'Creating...', 'Creando...', 'Wird erstellt...', 'Sozdaetsya...', 'Olusturuluyor...'),
  makeEntry('Criar plano', 'Create plan', 'Crear plan', 'Plan erstellen', 'Sozdat plan', 'Plan olustur'),
  makeEntry('Carregando plano...', 'Loading plan...', 'Cargando plan...', 'Plan wird geladen...', 'Zagruzka plana...', 'Plan yukleniyor...'),
  makeEntry('Não foi possível carregar o plano selecionado.', 'Could not load selected plan.', 'No fue posible cargar el plan seleccionado.', 'Der ausgewaehlte Plan konnte nicht geladen werden.', 'Ne udalos zagruzit vybrannyy plan.', 'Secilen plan yuklenemedi.'),
  makeEntry('Passaporte', 'Passport', 'Pasaporte', 'Reisepass', 'Pasport', 'Pasaport'),
  makeEntry('Número do passaporte', 'Passport number', 'Numero de pasaporte', 'Passnummer', 'Nomer pasporta', 'Pasaport numarasi'),
  makeEntry('Salvar Plano', 'Save Plan', 'Guardar Plan', 'Plan speichern', 'Sohranit plan', 'Plani Kaydet'),
  makeEntry('Voos', 'Flights', 'Vuelos', 'Fluege', 'Reysy', 'Ucuslar'),
  makeEntry('Voo de Chegada', 'Arrival Flight', 'Vuelo de Llegada', 'Ankunftsflug', 'Reys pribytiya', 'Varis Ucusu'),
  makeEntry('Voo de Regresso', 'Departure Flight', 'Vuelo de Regreso', 'Rueckflug', 'Reys vyleta', 'Donus Ucusu'),
  makeEntry('Número do voo', 'Flight number', 'Numero de vuelo', 'Flugnummer', 'Nomer reysa', 'Ucus numarasi'),
  makeEntry('Companhia', 'Airline', 'Aerolinea', 'Fluggesellschaft', 'Aviakompaniya', 'Havayolu'),
  makeEntry('Aeroporto', 'Airport', 'Aeropuerto', 'Flughafen', 'Aeroport', 'Havalimani'),
  makeEntry('Salvar Voo de Chegada', 'Save Arrival Flight', 'Guardar Vuelo de Llegada', 'Ankunftsflug speichern', 'Sohranit reys pribytiya', 'Varis ucusunu kaydet'),
  makeEntry('Salvar Voo de Regresso', 'Save Departure Flight', 'Guardar Vuelo de Regreso', 'Rueckflug speichern', 'Sohranit reys vyleta', 'Donus ucusunu kaydet'),
  makeEntry('Informações do Hotel', 'Hotel Information', 'Informacion del Hotel', 'Hotelinformationen', 'Informaciya ob otele', 'Otel Bilgileri'),
  makeEntry('Nome do hotel', 'Hotel name', 'Nombre del hotel', 'Hotelname', 'Nazvanie otelya', 'Otel adi'),
  makeEntry('Telefone do hotel', 'Hotel phone', 'Telefono del hotel', 'Hoteltelefon', 'Telefon otelya', 'Otel telefonu'),
  makeEntry('Endereço', 'Address', 'Direccion', 'Adresse', 'Adres', 'Adres'),
  makeEntry('Número do quarto', 'Room number', 'Numero de habitacion', 'Zimmernummer', 'Nomer komnaty', 'Oda numarasi'),
  makeEntry('Link do Google Maps', 'Google Maps link', 'Enlace de Google Maps', 'Google Maps Link', 'Ssylka Google Maps', 'Google Maps baglantisi'),
  makeEntry('Salvar Hotel', 'Save Hotel', 'Guardar Hotel', 'Hotel speichern', 'Sohranit otel', 'Oteli Kaydet'),
  makeEntry('Editar Transfer', 'Edit Transfer', 'Editar Traslado', 'Transfer bearbeiten', 'Redaktirovat transfer', 'Transferi Duzenle'),
  makeEntry('Adicionar Transfer', 'Add Transfer', 'Agregar Traslado', 'Transfer hinzufuegen', 'Dobavit transfer', 'Transfer Ekle'),
  makeEntry('Cancelar edição', 'Cancel editing', 'Cancelar edicion', 'Bearbeitung abbrechen', 'Otmenit redaktirovanie', 'Duzenlemeyi iptal et'),
  makeEntry('Titulo personalizado', 'Custom title', 'Titulo personalizado', 'Benutzerdefinierter Titel', 'Polzovatelskiy zagolovok', 'Ozel baslik'),
  makeEntry('Informe o título', 'Enter title', 'Ingresa el titulo', 'Titel eingeben', 'Vvedite zagolovok', 'Baslik girin'),
  makeEntry('Origem', 'Origin', 'Origen', 'Ursprung', 'Otpravlenie', 'Cikis'),
  makeEntry('Destino', 'Destination', 'Destino', 'Ziel', 'Punkt naznacheniya', 'Varis'),
  makeEntry('Salvar alterações', 'Save changes', 'Guardar cambios', 'Aenderungen speichern', 'Sohranit izmeneniya', 'Degisiklikleri kaydet'),
  makeEntry('Nenhum transfer cadastrado.', 'No transfer registered.', 'Ningun traslado registrado.', 'Kein Transfer registriert.', 'Net zaregistrirovannykh transferov.', 'Kayitli transfer yok.'),
  makeEntry('Mudar Status', 'Change Status', 'Cambiar Estado', 'Status aendern', 'Izmenit status', 'Durumu degistir'),
  makeEntry('Excluir', 'Delete', 'Eliminar', 'Loeschen', 'Udalit', 'Sil'),
  makeEntry('VISTO PELO PACIENTE', 'SEEN BY PATIENT', 'VISTO POR EL PACIENTE', 'VOM PATIENTEN GESEHEN', 'PROSMOTRENO PACIENTOM', 'HASTA TARAFINDAN GORULDU'),
  makeEntry('Status alterado para', 'Status changed to', 'Estado cambiado a', 'Status geaendert zu', 'Status izmenen na', 'Durum su olarak degisti'),
  makeEntry('Ordem dos transfers atualizada.', 'Transfer order updated.', 'Orden de traslados actualizada.', 'Transferreihenfolge aktualisiert.', 'Poryadok transferov obnovlen.', 'Transfer sirasi guncellendi.'),
  makeEntry('Não foi possível reordenar os transfers.', 'Could not reorder transfers.', 'No fue posible reordenar los traslados.', 'Transfers konnten nicht neu sortiert werden.', 'Ne udalos pereuporyadochit transfery.', 'Transferler yeniden siralanamadi.'),
  makeEntry('Selecione um paciente para criar o plano.', 'Select a patient to create the plan.', 'Selecciona un paciente para crear el plan.', 'Waehlen Sie einen Patienten, um den Plan zu erstellen.', 'Vyberite pacienta dlya sozdaniya plana.', 'Plani olusturmak icin bir hasta secin.'),
  makeEntry('Preencha número, data, hora e aeroporto do voo.', 'Fill flight number, date, time and airport.', 'Completa numero, fecha, hora y aeropuerto del vuelo.', 'Bitte Flugnummer, Datum, Uhrzeit und Flughafen ausfuellen.', 'Zapolnite nomer reysa, datu, vremya i aeroport.', 'Ucus numarasi, tarih, saat ve havalimanini doldurun.'),
  makeEntry('Preencha os campos obrigatórios do hotel.', 'Fill hotel required fields.', 'Completa los campos obligatorios del hotel.', 'Pflichtfelder des Hotels ausfuellen.', 'Zapolnite obyazatelnye polya otelya.', 'Otel zorunlu alanlarini doldurun.'),
  makeEntry('Preencha os campos obrigatórios do transfer.', 'Fill transfer required fields.', 'Completa los campos obligatorios del traslado.', 'Pflichtfelder des Transfers ausfuellen.', 'Zapolnite obyazatelnye polya transfera.', 'Transfer zorunlu alanlarini doldurun.'),
  makeEntry('Deseja remover este transfer?', 'Do you want to remove this transfer?', '¿Deseas eliminar este traslado?', 'Moechten Sie diesen Transfer entfernen?', 'Udalyat etot transfer?', 'Bu transfer silinsin mi?'),

  makeEntry('Pós-operatório', 'Post-op', 'Postoperatorio', 'Post-op', 'Post-op', 'Post-op'),
  makeEntry(
    'Monitore pacientes em recuperação, identifique riscos e acompanhe a evolução clínica.',
    'Monitor recovering patients, identify risks and track clinical progress.',
    'Monitorea pacientes en recuperacion, identifica riesgos y acompanha el progreso clinico.',
    'Ueberwachen Sie Patienten in Erholung, erkennen Sie Risiken und verfolgen Sie den klinischen Verlauf.',
    'Kontroliruyte vosstanavlivayushchikhsya pacientov, opredelyayte riski i otslezhivayte klinicheskuyu dinamiku.',
    'Iyilesen hastalari izleyin, riskleri belirleyin ve klinik gelisimi takip edin.',
  ),
  makeEntry('Pacientes em pós-op', 'Post-op patients', 'Pacientes en post-op', 'Post-op Patienten', 'Pacienty post-op', 'Post-op hastalari'),
  makeEntry('Com alerta', 'With alert', 'Con alerta', 'Mit Warnung', 'S preduprezhdeniem', 'Uyarili'),
  makeEntry('Sem check-in hoje', 'No check-in today', 'Sin check-in hoy', 'Kein Check-in heute', 'Bez chek-ina segodnya', 'Bugun check-in yok'),
  makeEntry('Concluídos', 'Completed', 'Completados', 'Abgeschlossen', 'Zaversheno', 'Tamamlandi'),
  makeEntry('Todos', 'All', 'Todos', 'Alle', 'Vse', 'Tum'),
  makeEntry('Urgentes', 'Urgent', 'Urgentes', 'Dringend', 'Srochnye', 'Acil'),
  makeEntry('Sem check-in', 'Without check-in', 'Sin check-in', 'Ohne Check-in', 'Bez chek-ina', 'Check-in yok'),
  makeEntry('paciente(s) encontrado(s)', 'patient(s) found', 'paciente(s) encontrado(s)', 'Patient(en) gefunden', 'naydeno patientov', 'hasta bulundu'),
  makeEntry('DIA ATUAL', 'CURRENT DAY', 'DIA ACTUAL', 'AKTUELLER TAG', 'TEKUSHCHIY DEN', 'MEVCUT GUN'),
  makeEntry('ÚLTIMO CHECK-IN', 'LAST CHECK-IN', 'ULTIMO CHECK-IN', 'LETZTER CHECK-IN', 'POSLEDNIY CHECK-IN', 'SON CHECK-IN'),
  makeEntry('STATUS CLÍNICO', 'CLINICAL STATUS', 'ESTADO CLINICO', 'KLINISCHER STATUS', 'KLINICHESKIY STATUS', 'KLINIK DURUM'),
  makeEntry('AÇÃO', 'ACTION', 'ACCION', 'AKTION', 'DEYSTVIE', 'AKSIYON'),
  makeEntry('Carregando pós-operatórios...', 'Loading post-op journeys...', 'Cargando post-operatorios...', 'Post-op Verlaeufe werden geladen...', 'Zagruzka post-op dannykh...', 'Post-op kayitlari yukleniyor...'),
  makeEntry('Não foi possível carregar os pós-operatórios.', 'Could not load post-op journeys.', 'No fue posible cargar los post-operatorios.', 'Post-op Verlaeufe konnten nicht geladen werden.', 'Ne udalos zagruzit post-op dannye.', 'Post-op verileri yuklenemedi.'),
  makeEntry('Nenhum paciente encontrado com os filtros atuais.', 'No patients found with current filters.', 'No se encontraron pacientes con los filtros actuales.', 'Keine Patienten mit den aktuellen Filtern gefunden.', 'Po tekushchim filtram pacienty ne naydeny.', 'Mevcut filtrelerle hasta bulunamadi.'),
  makeEntry('Urgente', 'Urgent', 'Urgente', 'Dringend', 'Srochno', 'Acil'),
  makeEntry('Ver', 'View', 'Ver', 'Ansehen', 'Posmotret', 'Gor'),
  makeEntry('Pós-operatório •', 'Post-op •', 'Postoperatorio •', 'Post-op •', 'Post-op •', 'Post-op •'),
  makeEntry('Carregando pós-operatório...', 'Loading post-op...', 'Cargando postoperatorio...', 'Post-op wird geladen...', 'Zagruzka post-op...', 'Post-op yukleniyor...'),
  makeEntry('Não foi possível carregar os dados do pós-operatório agora.', 'Could not load post-op data right now.', 'No fue posible cargar los datos del postoperatorio ahora.', 'Post-op Daten konnten gerade nicht geladen werden.', 'Ne udalos zagruzit dannye post-op seychas.', 'Post-op verileri simdi yuklenemedi.'),
  makeEntry('Nenhuma jornada pós-operatória encontrada para este paciente.', 'No post-op journey found for this patient.', 'No se encontro jornada postoperatoria para este paciente.', 'Keine Post-op Reise fuer diesen Patienten gefunden.', 'Dlya etogo pacienta ne nayden post-op marshrut.', 'Bu hasta icin post-op sureci bulunamadi.'),
  makeEntry('Dia atual:', 'Current day:', 'Dia actual:', 'Aktueller Tag:', 'Tekushchiy den:', 'Mevcut gun:'),
  makeEntry('Concluindo...', 'Completing...', 'Completando...', 'Wird abgeschlossen...', 'Zavershenie...', 'Tamamlaniyor...'),
  makeEntry('Concluir pós-op', 'Complete post-op', 'Completar post-op', 'Post-op abschliessen', 'Zavershit post-op', 'Post-op tamamla'),
  makeEntry('Status do paciente', 'Patient status', 'Estado del paciente', 'Patientenstatus', 'Status pacienta', 'Hasta durumu'),
  makeEntry('Ação sugerida', 'Suggested action', 'Accion sugerida', 'Empfohlene Aktion', 'Rekomenduemoe deystvie', 'Onerilen aksiyon'),
  makeEntry('Tickets urgentes', 'Urgent tickets', 'Tickets urgentes', 'Dringende Tickets', 'Srochnye tikety', 'Acil ticketlar'),
  makeEntry('Nenhum ticket urgente para este paciente.', 'No urgent ticket for this patient.', 'Ningun ticket urgente para este paciente.', 'Kein dringendes Ticket fuer diesen Patienten.', 'Dlya etogo pacienta net srochnykh tiketov.', 'Bu hasta icin acil ticket yok.'),
  makeEntry('Aberto', 'Open', 'Abierto', 'Offen', 'Otkryt', 'Acik'),
  makeEntry('Visualizado', 'Viewed', 'Visto', 'Gesehen', 'Prosmotren', 'Goruldu'),
  makeEntry('Resolvido', 'Resolved', 'Resuelto', 'Geloest', 'Reshen', 'Cozuldu'),
  makeEntry('Baixa', 'Low', 'Baja', 'Niedrig', 'Nizkiy', 'Dusuk'),
  makeEntry('Média', 'Medium', 'Media', 'Mittel', 'Sredniy', 'Orta'),
  makeEntry('Alta', 'High', 'Alta', 'Hoch', 'Vysokiy', 'Yuksek'),
  makeEntry('Atualizando...', 'Updating...', 'Actualizando...', 'Aktualisiert...', 'Obnovlenie...', 'Guncelleniyor...'),
  makeEntry('Marcar como visualizado', 'Mark as viewed', 'Marcar como visto', 'Als gesehen markieren', 'Otmetit kak prosmotrennyy', 'Goruldu olarak isle'),
  makeEntry('Marcar como resolvido', 'Mark as resolved', 'Marcar como resuelto', 'Als geloest markieren', 'Otmetit kak reshennyy', 'Cozuldu olarak isle'),
  makeEntry('Dias sem check-in', 'Days without check-in', 'Dias sin check-in', 'Tage ohne Check-in', 'Dney bez chek-ina', 'Check-in olmadan gun'),
  makeEntry('Início da jornada', 'Journey start', 'Inicio de jornada', 'Start der Reise', 'Nachalo marshruta', 'Surecin baslangici'),
  makeEntry('Última febre reportada', 'Last reported fever', 'Ultima fiebre reportada', 'Zuletzt gemeldetes Fieber', 'Poslednyaya zafiksirovannaya temperatura', 'Son bildirilen ates'),
  makeEntry('Sim', 'Yes', 'Si', 'Ja', 'Da', 'Evet'),
  makeEntry('Não', 'No', 'No', 'Nein', 'Net', 'Hayir'),
  makeEntry('Check-ins', 'Check-ins', 'Check-ins', 'Check-ins', 'Check-ins', 'Check-ins'),
  makeEntry('Nenhum check-in enviado.', 'No check-in sent.', 'Ningun check-in enviado.', 'Kein Check-in gesendet.', 'Chek-in ne otpravlyalsya.', 'Check-in gonderilmedi.'),
  makeEntry('Dia', 'Day', 'Dia', 'Tag', 'Den', 'Gun'),
  makeEntry('Febre', 'Fever', 'Fiebre', 'Fieber', 'Temperatura', 'Ates'),
  makeEntry('Enviado em', 'Sent at', 'Enviado en', 'Gesendet am', 'Otpravleno v', 'Gonderim zamani'),
  makeEntry('Checklist', 'Checklist', 'Checklist', 'Checkliste', 'Chek-list', 'Kontrol listesi'),
  makeEntry('Nenhum checklist disponível.', 'No checklist available.', 'No hay checklist disponible.', 'Keine Checkliste verfuegbar.', 'Chek-list nedostupen.', 'Kullanilabilir kontrol listesi yok.'),
  makeEntry('Pendente', 'Pending', 'Pendiente', 'Ausstehend', 'V ozhidanii', 'Beklemede'),
  makeEntry('Fotos', 'Photos', 'Fotos', 'Fotos', 'Foto', 'Fotograflar'),
  makeEntry('Nenhuma foto enviada.', 'No photo uploaded.', 'Ninguna foto enviada.', 'Kein Foto hochgeladen.', 'Foto ne zagruzheno.', 'Fotograf yuklenmedi.'),
  makeEntry('Sem check-in', 'No check-in', 'Sin check-in', 'Kein Check-in', 'Bez chek-ina', 'Check-in yok'),
  makeEntry('Em risco', 'At risk', 'En riesgo', 'In Risiko', 'V riske', 'Riskte'),
  makeEntry('Atrasado', 'Delayed', 'Atrasado', 'Verspaetet', 'Zaderzhka', 'Gecikmis'),
  makeEntry('Dor elevada e febre no último check-in', 'High pain and fever in the last check-in', 'Dolor alto y fiebre en el ultimo check-in', 'Hoher Schmerz und Fieber beim letzten Check-in', 'Vysokaya bol i temperatura v poslednem chek-ine', 'Son check-in kaydinda yuksek agri ve ates'),
  makeEntry('Dor elevada no último check-in', 'High pain in the last check-in', 'Dolor alto en el ultimo check-in', 'Hoher Schmerz beim letzten Check-in', 'Vysokaya bol v poslednem chek-ine', 'Son check-inde yuksek agri'),
  makeEntry('Febre no último check-in', 'Fever in the last check-in', 'Fiebre en el ultimo check-in', 'Fieber beim letzten Check-in', 'Temperatura v poslednem chek-ine', 'Son check-inde ates'),
  makeEntry('Sinais clínicos de atenção foram identificados', 'Clinical warning signs were identified', 'Se identificaron signos clinicos de alerta', 'Klinische Warnzeichen wurden identifiziert', 'Byli obnaruzheny klinicheskie signaly trevogi', 'Klinik uyari isaretleri tespit edildi'),
  makeEntry('Paciente sem check-in hoje', 'Patient without check-in today', 'Paciente sin check-in hoy', 'Patient ohne Check-in heute', 'Pacient bez chek-ina segodnya', 'Bugun check-in yapmayan hasta'),
  makeEntry('Paciente sem check-in há', 'Patient without check-in for', 'Paciente sin check-in hace', 'Patient ohne Check-in seit', 'Pacient bez chek-ina uzhe', 'Su suredir check-in yapmayan hasta'),
  makeEntry('dias', 'days', 'dias', 'Tage', 'dney', 'gun'),
  makeEntry('Paciente com check-in em dia e sem sinais críticos no último registro', 'Patient with up-to-date check-in and no critical signs in the last record', 'Paciente con check-in al dia y sin signos criticos en el ultimo registro', 'Patient mit aktuellem Check-in und ohne kritische Zeichen im letzten Eintrag', 'Pacient s aktualnym chek-inom i bez kriticheskikh priznakov v posledney zapisi', 'Hasta check-inleri guncel ve son kayitta kritik belirti yok'),
  makeEntry('Contato imediato recomendado para avaliação clínica', 'Immediate contact recommended for clinical assessment', 'Contacto inmediato recomendado para evaluacion clinica', 'Sofortiger Kontakt fuer klinische Bewertung empfohlen', 'Rekomenduetsya nemedlennyy kontakt dlya klinicheskoy otsenki', 'Klinik degerlendirme icin acil iletisim onerilir'),
  makeEntry('Entrar em contato com o paciente para verificar ausência de check-in', 'Contact the patient to verify missing check-in', 'Contactar al paciente para verificar ausencia de check-in', 'Patienten kontaktieren, um fehlenden Check-in zu pruefen', 'Svyazatsya s pacientom, chtoby proverit otsutstvie chek-ina', 'Check-in eksigini dogrulamak icin hastayla iletisime gecin'),
  makeEntry('Nenhuma ação necessária no momento', 'No action needed right now', 'Ninguna accion necesaria por ahora', 'Derzeit keine Aktion erforderlich', 'Seychas deystviy ne trebuetsya', 'Su an herhangi bir aksiyon gerekmiyor'),

  makeEntry('Support', 'Support', 'Soporte', 'Support', 'Podderzhka', 'Destek'),
  makeEntry('System', 'System', 'Sistema', 'System', 'Sistema', 'Sistem'),
]

const lookup = buildLookup(entries)
const replacementRules = buildReplacementRules(entries)
const textOriginal = new WeakMap<Text, string>()
const attrOriginal = new WeakMap<Element, Map<string, string>>()
let mutationObserver: MutationObserver | null = null
let applying = false

export function startDomTranslator(language: SupportedLanguage): () => void {
  if (typeof document === 'undefined') {
    return () => undefined
  }

  const apply = () => {
    if (applying) return
    applying = true
    try {
      translateTextNodes(language)
      translateAttributes(language)
    } finally {
      applying = false
    }
  }

  apply()

  mutationObserver?.disconnect()
  mutationObserver = new MutationObserver(() => apply())
  mutationObserver.observe(document.body, {
    subtree: true,
    childList: true,
    characterData: true,
    attributes: true,
    attributeFilter: [...ATTRIBUTES_TO_TRANSLATE],
  })

  return () => {
    mutationObserver?.disconnect()
    mutationObserver = null
  }
}

function translateTextNodes(language: SupportedLanguage) {
  const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT)
  let current = walker.nextNode()
  while (current) {
    const textNode = current as Text
    const parent = textNode.parentElement
    if (parent && !shouldIgnoreElement(parent)) {
      const currentValue = textNode.textContent ?? ''
      const originalValue = textOriginal.get(textNode) ?? currentValue
      textOriginal.set(textNode, originalValue)
      const translated = translateAny(originalValue, language)
      if (translated && translated !== currentValue) {
        textNode.textContent = translated
      }
    }
    current = walker.nextNode()
  }
}

function translateAttributes(language: SupportedLanguage) {
  const elements = document.body.querySelectorAll<HTMLElement>('*')
  elements.forEach((element) => {
    if (shouldIgnoreElement(element)) return

    ATTRIBUTES_TO_TRANSLATE.forEach((attribute) => {
      const currentValue = element.getAttribute(attribute)
      if (!currentValue) return

      const originals = attrOriginal.get(element) ?? new Map<string, string>()
      const originalValue = originals.get(attribute) ?? currentValue
      originals.set(attribute, originalValue)
      attrOriginal.set(element, originals)

      const translated = translateAny(originalValue, language)
      if (translated && translated !== currentValue) {
        element.setAttribute(attribute, translated)
      }
    })
  })
}

function shouldIgnoreElement(element: Element | null): boolean {
  if (!element) return true
  return Boolean(
    element.closest('[data-i18n-ignore="true"],svg,canvas,script,style'),
  )
}

function makeEntry(
  pt: string,
  en: string,
  es: string,
  de: string,
  ru: string,
  tr: string,
  aliases: string[] = [],
): Entry {
  return {
    phrases: [pt, en, ...aliases],
    translations: { pt, en, es, de, ru, tr },
  }
}

function buildLookup(list: Entry[]): Map<string, Translations> {
  const map = new Map<string, Translations>()
  list.forEach((entry) => {
    entry.phrases.forEach((phrase) => {
      const normalized = normalize(phrase)
      if (!normalized) return
      map.set(normalized, entry.translations)
    })
    Object.values(entry.translations).forEach((phrase) => {
      const normalized = normalize(phrase)
      if (!normalized) return
      map.set(normalized, entry.translations)
    })
  })
  return map
}

type ReplacementRule = { source: string; target: string; pattern: RegExp }

function buildReplacementRules(
  list: Entry[],
): Record<SupportedLanguage, ReplacementRule[]> {
  const initial: Record<SupportedLanguage, ReplacementRule[]> = {
    tr: [],
    ru: [],
    en: [],
    de: [],
    es: [],
    pt: [],
  }

  list.forEach((entry) => {
    const sources = [...entry.phrases, ...Object.values(entry.translations)]
      .map((value) => normalize(value))
      .filter(Boolean)
    ;(Object.keys(initial) as SupportedLanguage[]).forEach((language) => {
      const target = entry.translations[language]
      sources.forEach((source) => {
        if (source !== target) {
          const pattern = createReplacementPattern(source)
          initial[language].push({ source, target, pattern })
        }
      })
    })
  })

  ;(Object.keys(initial) as SupportedLanguage[]).forEach((language) => {
    initial[language].sort((a, b) => b.source.length - a.source.length)
  })

  return initial
}

function createReplacementPattern(source: string): RegExp {
  const escaped = escapeRegex(source)
  if (isAsciiSingleWord(source)) {
    return new RegExp(`\\b${escaped}\\b`, 'g')
  }
  return new RegExp(escaped, 'g')
}

function isAsciiSingleWord(value: string): boolean {
  return /^[a-z0-9_]+$/i.test(value)
}

function escapeRegex(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
}

function translateAny(value: string, language: SupportedLanguage): string | null {
  const exact = translateExact(value, language)
  if (exact) {
    return exact
  }

  const rules = replacementRules[language]
  let translated = value
  for (const rule of rules) {
    const next = translated.replace(rule.pattern, rule.target)
    if (next !== translated) {
      translated = next
    }
  }

  return translated === value ? null : translated
}

function translateExact(value: string, language: SupportedLanguage): string | null {
  const key = normalize(value)
  if (!key) return null

  const matched = lookup.get(key)
  if (!matched) return null
  const target = matched[language]
  if (!target) return null

  const leading = value.match(/^\s*/)?.[0] ?? ''
  const trailing = value.match(/\s*$/)?.[0] ?? ''
  return `${leading}${target}${trailing}`
}

function normalize(value?: string | null): string {
  if (typeof value !== 'string') return ''
  return value.replace(/\s+/g, ' ').trim()
}
