import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/gk_badge.dart';
import '../../../core/widgets/gk_button.dart';
import '../../../core/widgets/gk_card.dart';
import '../../../core/widgets/gk_loading_shimmer.dart';
import '../domain/postop_models.dart';
import 'postop_controller.dart';

class EvolutionScreen extends ConsumerStatefulWidget {
  const EvolutionScreen({super.key});

  @override
  ConsumerState<EvolutionScreen> createState() => _EvolutionScreenState();
}

class _EvolutionScreenState extends ConsumerState<EvolutionScreen> {
  double _split = 0.5;
  bool _allowPortfolio = false;
  bool _anonymous = true;
  bool _uploading = false;
  bool _ratingShown = false;

  Future<void> _pickAndUpload(PostOpJourney journey) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      await ref.read(postOpControllerProvider.notifier).uploadPhoto(
            journeyId: journey.id,
            dayNumber: journey.currentDay,
            path: file.path,
            isAnonymous: _anonymous,
          );
      ref.invalidate(journeyPhotosProvider(journey.id));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto enviada com sucesso.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao enviar foto de evolução.')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final journeyState = ref.watch(postOpControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Minha Evolução')),
      body: journeyState.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(16),
          child: GKLoadingShimmer(height: 240),
        ),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (journey) {
          if (journey == null) {
            return const Center(child: Text('Sem jornada ativa.'));
          }

          if (!_ratingShown && journey.currentDay >= 90) {
            _ratingShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) => _showRatingDialog());
          }

          final photosState = ref.watch(journeyPhotosProvider(journey.id));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'PREMIUM CARE PORTFOLIO',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: GKColors.neutral,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text('Minha Evolução', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const GKBadge(
                label: 'Privacidade ativa',
                background: Color(0xFFD8F2E0),
                foreground: GKColors.secondary,
              ),
              const SizedBox(height: 12),
              GKCard(
                child: Column(
                  children: [
                    SizedBox(
                      height: 220,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          return GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              setState(() {
                                _split = (_split + (details.delta.dx / width)).clamp(0.1, 0.9);
                              });
                            },
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF2F4558), Color(0xFF3B556C)],
                                      ),
                                    ),
                                    child: const Center(
                                      child: Text('ANTES', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: width * _split,
                                  top: 0,
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF0D5C73), Color(0xFF4A7C59)],
                                      ),
                                    ),
                                    child: const Center(
                                      child: Text('DEPOIS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: width * _split - 14,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 28,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(999),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x22000000),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(Icons.drag_indicator, color: GKColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Row(
                      children: [
                        Text('ANTES', style: TextStyle(fontWeight: FontWeight.w700, color: GKColors.neutral)),
                        Spacer(),
                        Text('DEPOIS', style: TextStyle(fontWeight: FontWeight.w700, color: GKColors.neutral)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GKCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Linha do tempo', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    photosState.when(
                      loading: () => const GKLoadingShimmer(height: 90),
                      error: (_, __) => const Text('Não foi possível carregar as fotos.'),
                      data: (photos) {
                        if (photos.isEmpty) {
                          return const Text('Ainda não há fotos enviadas.');
                        }
                        return SizedBox(
                          height: 96,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) => _PhotoThumb(photo: photos[index]),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _uploading ? null : () => _pickAndUpload(journey),
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.camera_alt_outlined),
                      label: const Text('Adicionar foto do dia'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GKCard(
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Autorizo o uso no portfólio'),
                      value: _allowPortfolio,
                      onChanged: (value) => setState(() => _allowPortfolio = value),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Manter minha identidade anônima'),
                      value: _anonymous,
                      onChanged: (value) => setState(() => _anonymous = value),
                    ),
                    const SizedBox(height: 8),
                    GKButton(
                      label: 'ASSINAR TERMO DE CONSENTIMENTO',
                      variant: GKButtonVariant.secondary,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Assinatura digital será habilitada em breve.')),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    GKButton(
                      label: 'Compartilhar no Instagram',
                      variant: GKButtonVariant.accent,
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Compartilhamento social será habilitado em breve.')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showRatingDialog() async {
    int stars = 5;
    final commentController = TextEditingController();
    bool anonymous = true;

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Avalie sua jornada'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (index) {
                        final active = index < stars;
                        return IconButton(
                          onPressed: () => setDialogState(() => stars = index + 1),
                          icon: Icon(
                            active ? Icons.star : Icons.star_border,
                            color: GKColors.accent,
                          ),
                        );
                      }),
                    ),
                    TextField(
                      controller: commentController,
                      maxLines: 3,
                      cursorColor: GKColors.primary,
                      style: const TextStyle(color: GKColors.darkBackground),
                      decoration: const InputDecoration(
                        labelText: 'Comentário (opcional)',
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Avaliação anônima'),
                      value: anonymous,
                      onChanged: (value) => setDialogState(() => anonymous = value ?? true),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Fechar'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(content: Text('Avaliação enviada com sucesso.')),
                      );
                    },
                    child: const Text('Enviar avaliação'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      commentController.dispose();
    }
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.photo});

  final EvolutionPhotoItem photo;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: photo.photoUrl,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: const Color(0xFFE2E8F0)),
            errorWidget: (_, __, ___) => Container(
              color: const Color(0xFFE2E8F0),
              width: 72,
              height: 72,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('DIA ${photo.dayNumber}', style: const TextStyle(fontSize: 11)),
      ],
    );
  }
}
