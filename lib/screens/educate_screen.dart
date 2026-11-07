import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/avatar.dart';
import '../widgets/emergency_links.dart';
import 'lumai_screen.dart';

/// Educate = comunidad de Aliada.
///
/// El centro es la red: publicaciones de aliadas y mentoras, reacciones,
/// comentarios, encuestas, espacios y encuentros. Las guías de orientación y
/// LumAI quedan como recursos secundarios, no como el destino de todo.
class EducateScreen extends StatefulWidget {
  const EducateScreen({super.key});
  @override
  State<EducateScreen> createState() => _EducateScreenState();
}

class _EducateScreenState extends State<EducateScreen> {
  String _filter = 'Para ti';
  // Votos por encuesta: clave = post.id, valor = índice de opción elegida.
  final _pollVotes = <String, int>{};
  final _liked = <String>{};
  final _saved = <String>{};
  final _joined = <String>{};
  final _attending = <String>{};
  final _following = <String>{};
  final _localPosts = <_Post>[];

  final Map<String, List<_Comment>> _comments = {
    'julia': [
      _Comment('Andrea Salas', 'Gracias por decirlo. A mí me pasó algo parecido y no sabía cómo llamarlo.', const Color(0xFF3D9970)),
      _Comment('Camila Rocca', '“No es tu culpa” es lo que más necesitaba leer hoy.', const Color(0xFF3D7EC9)),
    ],
    'colectivo': [
      _Comment('Julia Linarez', 'Voto por límites y consentimiento. Siento que es lo que más dudas nos da.', const Color(0xFF765AD0)),
      _Comment('Vale Ríos', '¿Se puede llevar a una amiga que no es de la universidad?', const Color(0xFFB0763F)),
      _Comment('Colectivo Aliadas', 'Sí, puede venir contigo. Solo avísanos al inscribirte.', AppColors.primary),
    ],
    'andrea': [
      _Comment('Camila Rocca', 'Acompañar sin opinar de más también es una forma de cuidar.', const Color(0xFF3D7EC9)),
      _Comment('Julia Linarez', 'Me hubiera gustado tener a alguien así en primer ciclo.', const Color(0xFF765AD0)),
    ],
    'camila': [
      _Comment('Andrea Salas', 'Lo de no borrar el chat me lo repitió la psicóloga. Es clave.', const Color(0xFF3D9970)),
    ],
  };

  List<_Post> get _posts {
    final all = [..._localPosts, ..._demoPosts];
    if (_filter == 'Para ti') return all;
    final topic = switch (_filter) {
      'Testimonios' => 'Testimonio',
      'Consejos' => 'Consejo',
      _ => 'Pregunta',
    };
    return all.where((p) => p.topic == topic).toList();
  }

  @override
  Widget build(BuildContext context) {
    final me = AppState.instance;
    return Container(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 140),
          children: [
            const _CommunityHeader(),
            const SizedBox(height: 18),
            _PeopleStrip(
              name: me.nombre,
              following: _following,
              onCompose: () => _openComposer(),
              onOpen: _openProfile,
            ),
            const SizedBox(height: 14),
            _ComposerCard(
              name: me.nombre,
              onTap: () => _openComposer(),
              onTopic: (t) => _openComposer(topic: t),
            ),
            const SizedBox(height: 22),
            const _SectionHead(kicker: 'EN LA COMUNIDAD', title: 'Lo que están hablando'),
            const SizedBox(height: 12),
            _FilterBar(selected: _filter, onSelect: (f) => setState(() => _filter = f)),
            const SizedBox(height: 12),
            for (final p in _posts) ...[
              _PostCard(
                post: p,
                liked: _liked.contains(p.id),
                saved: _saved.contains(p.id),
                likes: p.likes + (_liked.contains(p.id) ? 1 : 0),
                commentCount: _comments[p.id]?.length ?? 0,
                vote: _pollVotes[p.id],
                onLike: () => _toggleLike(p),
                onComment: () => _openComments(p),
                onSave: () => _toggleSave(p),
                onShare: () => _share(p),
                onVote: (i) => setState(() => _pollVotes[p.id] = i),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 8),
            const _SectionHead(kicker: 'APRENDE', title: 'Aprende en 4 minutos'),
            const SizedBox(height: 12),
            _GuideCarousel(onOpen: _openGuide),
            const SizedBox(height: 26),
            const _SectionHead(kicker: 'ENCUENTROS', title: 'Próximos encuentros'),
            const SizedBox(height: 12),
            for (var i = 0; i < _events.length; i++) ...[
              _EventCard(
                event: _events[i],
                attending: _attending.contains(_events[i].title),
                onToggle: () => setState(() {
                  _attending.contains(_events[i].title)
                      ? _attending.remove(_events[i].title)
                      : _attending.add(_events[i].title);
                }),
              ),
              if (i < _events.length - 1) const SizedBox(height: 10),
            ],
            const SizedBox(height: 26),
            const _SectionHead(kicker: 'ESPACIOS', title: 'Espacios de la comunidad'),
            const SizedBox(height: 12),
            _SpacesGrid(
              joined: _joined,
              onToggle: (name) => setState(() {
                _joined.contains(name) ? _joined.remove(name) : _joined.add(name);
              }),
            ),
            const SizedBox(height: 18),
            const _GuidelinesCard(),
            const SizedBox(height: 18),
            const _EmergencyCard(),
            const SizedBox(height: 18),
            _LumaiRow(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LumaiScreen()))),
            const SizedBox(height: 16),
            Text(
              'Comunidad de demostración. Los testimonios son ejemplos y se muestran con permiso. '
              'El contenido educativo está en revisión por psicólogas antes del piloto y no sustituye una evaluación profesional '
              'ni el protocolo de tu universidad.',
              textAlign: TextAlign.center,
              style: AppText.caption.copyWith(fontSize: 10.5, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGuide(_Guide guide) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _GuideSheet(
        guide: guide,
        onAskLumai: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LumaiScreen())),
      ),
    );
  }

  Future<void> _openComposer({String topic = 'Testimonio'}) async {
    final post = await showModalBottomSheet<_Post>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _ComposerSheet(initialTopic: topic),
    );
    if (post == null || !mounted) return;
    setState(() => _localPosts.insert(0, post));
    _toast('Tu publicación ya está en la comunidad');
  }

  Future<void> _openComments(_Post post) async {
    final current = List<_Comment>.of(_comments[post.id] ?? const <_Comment>[]);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _CommentsSheet(
        post: post,
        comments: current,
        onAdd: (text) {
          setState(() {
            _comments.putIfAbsent(post.id, () => <_Comment>[]).add(
                  _Comment(AppState.instance.nombre, text, AppColors.primary),
                );
          });
        },
      ),
    );
  }

  Future<void> _openProfile(_Person person) async {
    final alreadyFollowing = _following.contains(person.name);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => _ProfileSheet(
        person: person,
        initiallyFollowing: alreadyFollowing,
        onToggle: (v) => setState(() {
          v ? _following.add(person.name) : _following.remove(person.name);
        }),
      ),
    );
  }

  void _toggleLike(_Post post) {
    setState(() {
      _liked.contains(post.id) ? _liked.remove(post.id) : _liked.add(post.id);
    });
  }

  void _toggleSave(_Post post) {
    final now = !_saved.contains(post.id);
    setState(() {
      now ? _saved.add(post.id) : _saved.remove(post.id);
    });
    _toast(now ? 'Publicación guardada' : 'Publicación quitada de guardados');
  }

  Future<void> _share(_Post post) async {
    await Clipboard.setData(ClipboardData(text: '${post.author} en Aliada: “${post.text}”'));
    if (mounted) _toast('Texto copiado para compartir');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Encabezado y red de aliadas
// ─────────────────────────────────────────────────────────────────────────────

class _CommunityHeader extends StatelessWidget {
  const _CommunityHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 18,
                height: 4,
                decoration: BoxDecoration(
                  gradient: AppColors.limeGradient,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'COMUNIDAD ALIADA',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.label,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Text('Educate', style: AppText.h1.copyWith(fontSize: 32)),
            const SizedBox(height: 5),
            Text(
              'Aprende, comparte y acompáñate con otras estudiantes.',
              style: AppText.caption.copyWith(fontSize: 12.5, height: 1.45),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        const _OnlinePill(),
      ],
    );
  }
}

class _OnlinePill extends StatelessWidget {
  const _OnlinePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: const Row(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          width: 7,
          height: 7,
          child: DecoratedBox(
            decoration: BoxDecoration(color: AppColors.limeDeep, shape: BoxShape.circle),
          ),
        ),
        SizedBox(width: 6),
        Text(
          '32 en línea',
          style: TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 9.8, color: AppColors.textSoft),
        ),
      ]),
    );
  }
}

class _PeopleStrip extends StatelessWidget {
  const _PeopleStrip({required this.name, required this.following, required this.onCompose, required this.onOpen});
  final String name;
  final Set<String> following;
  final VoidCallback onCompose;
  final ValueChanged<_Person> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Tu red', style: AppText.label.copyWith(color: AppColors.textSoft, fontSize: 10.5)),
        const Spacer(),
        Text(
          'Aliadas de tu universidad',
          style: TextStyle(fontFamily: AppFonts.ui, fontSize: 9.8, color: AppColors.gray),
        ),
      ]),
      const SizedBox(height: 9),
      SizedBox(
        height: 88,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _people.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, i) {
            if (i == 0) {
              return _Story(
                initialsName: name,
                color: AppColors.primary,
                label: 'Tu historia',
                mine: true,
                onTap: onCompose,
              );
            }
            final p = _people[i - 1];
            return _Story(
              initialsName: p.name,
              color: p.color,
              label: p.name.split(' ').first,
              following: following.contains(p.name),
              onTap: () => onOpen(p),
            );
          },
        ),
      ),
    ]);
  }
}

class _Story extends StatelessWidget {
  const _Story({
    required this.initialsName,
    required this.color,
    required this.label,
    required this.onTap,
    this.mine = false,
    this.following = false,
  });
  final String initialsName;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final bool mine;
  final bool following;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: mine || following
                    ? AppColors.limeGradient
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, color.withValues(alpha: 0.5)],
                      ),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                child: Avatar(name: initialsName, size: 46, color: color, ring: Colors.transparent),
              ),
            ),
            if (mine)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                  child: const Icon(Icons.add_rounded, size: 12, color: Colors.white),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppFonts.ui,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
              color: AppColors.textSoft,
            ),
          ),
        ]),
      ),
    );
  }
}

class _ComposerCard extends StatelessWidget {
  const _ComposerCard({required this.name, required this.onTap, required this.onTopic});
  final String name;
  final VoidCallback onTap;
  final ValueChanged<String> onTopic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(children: [
        Row(children: [
          Avatar(name: name, size: 40, color: AppColors.primary, ring: AppColors.primaryMist),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.primaryMist,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: const Row(children: [
                  Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Comparte algo con la comunidad…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: AppFonts.ui, fontSize: 12.3, color: AppColors.gray),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 6),
        Row(children: [
          _ComposeAction(icon: Icons.favorite_border_rounded, label: 'Testimonio', onTap: () => onTopic('Testimonio')),
          _ComposeAction(icon: Icons.lightbulb_outline_rounded, label: 'Consejo', onTap: () => onTopic('Consejo')),
          _ComposeAction(icon: Icons.help_outline_rounded, label: 'Pregunta', onTap: () => onTopic('Pregunta')),
        ]),
      ]),
    );
  }
}

class _ComposeAction extends StatelessWidget {
  const _ComposeAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: AppFonts.ui,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.8,
                  color: AppColors.primary,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelect});
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label) {
      final sel = label == selected;
      return Material(
        color: sel ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: () => onSelect(label),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: sel ? AppColors.primary : AppColors.border),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontWeight: FontWeight.w700,
                fontSize: 11.3,
                color: sel ? Colors.white : AppColors.textSoft,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip('Para ti'),
          const SizedBox(width: 8),
          chip('Testimonios'),
          const SizedBox(width: 8),
          chip('Consejos'),
          const SizedBox(width: 8),
          chip('Preguntas'),
        ],
      ),
    );
  }
}

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.kicker, required this.title});
  final String kicker;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 4,
          height: 14,
          decoration: BoxDecoration(
            gradient: AppColors.limeGradient,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            kicker,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.label.copyWith(color: AppColors.primary, fontSize: 10),
          ),
        ),
      ]),
      const SizedBox(height: 6),
      Text(title, style: AppText.h2.copyWith(fontSize: 19)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Publicaciones
// ─────────────────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.liked,
    required this.saved,
    required this.likes,
    required this.commentCount,
    required this.vote,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
    required this.onVote,
  });
  final _Post post;
  final bool liked;
  final bool saved;
  final int likes;
  final int commentCount;
  final int? vote;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final ValueChanged<int> onVote;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Avatar(name: post.author, size: 42, color: post.color, ring: AppColors.primaryMist),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(
                  child: Text(
                    post.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong.copyWith(fontSize: 13.4),
                  ),
                ),
                if (post.official) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified_rounded, size: 14, color: AppColors.primary),
                ],
              ]),
              const SizedBox(height: 2),
              Text(
                '${post.role} · ${post.time}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.caption.copyWith(fontSize: 10.6),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          _TopicPill(topic: post.topic),
        ]),
        const SizedBox(height: 11),
        Text(post.text, style: AppText.body.copyWith(fontSize: 13.2, height: 1.5)),
        if (post.quote != null) ...[
          const SizedBox(height: 11),
          _Quote(text: post.quote!),
        ],
        if (post.poll != null) ...[
          const SizedBox(height: 12),
          _PollCard(poll: post.poll!, vote: vote, onVote: onVote),
        ],
        const SizedBox(height: 6),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 2),
        Row(children: [
          _PostAction(
            icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            label: '$likes',
            color: liked ? AppColors.danger : AppColors.gray,
            onTap: onLike,
          ),
          _PostAction(
            icon: Icons.chat_bubble_outline_rounded,
            label: '$commentCount',
            color: AppColors.gray,
            onTap: onComment,
          ),
          _PostAction(
            icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            label: saved ? 'Guardado' : 'Guardar',
            color: saved ? AppColors.primary : AppColors.gray,
            onTap: onSave,
          ),
          _PostAction(
            icon: Icons.share_outlined,
            label: 'Compartir',
            color: AppColors.gray,
            onTap: onShare,
          ),
        ]),
      ]),
    );
  }
}

class _TopicPill extends StatelessWidget {
  const _TopicPill({required this.topic});
  final String topic;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (topic) {
      'Testimonio' => (const Color(0xFFEFEAFB), AppColors.primary),
      'Consejo' => (const Color(0xFFE8F6E3), const Color(0xFF3E7A2E)),
      'Pregunta' => (const Color(0xFFFFF3E2), const Color(0xFF9A5B00)),
      _ => (AppColors.primaryMist, AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.pill)),
      child: Text(
        topic,
        style: TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 9.3, color: fg),
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3EEFF), Color(0xFFFBF9FF)],
        ),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.format_quote_rounded, color: AppColors.primary, size: 20),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: AppText.bodyStrong.copyWith(fontSize: 12.6, height: 1.45, color: AppColors.primaryDark),
          ),
        ),
      ]),
    );
  }
}

class _PollCard extends StatelessWidget {
  const _PollCard({required this.poll, required this.vote, required this.onVote});
  final _Poll poll;
  final int? vote;
  final ValueChanged<int> onVote;
  static const _pct = [48, 31, 21];

  @override
  Widget build(BuildContext context) {
    final voted = vote != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.primaryMist, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(7)),
            child: const Icon(Icons.poll_outlined, size: 13, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'ENCUESTA',
              style: TextStyle(
                fontFamily: AppFonts.ui,
                fontWeight: FontWeight.w800,
                fontSize: 9,
                letterSpacing: 1,
                color: AppColors.primary,
              ),
            ),
          ),
          Text(
            voted ? '128 votos' : 'Vota',
            style: const TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w600, fontSize: 9.8, color: AppColors.gray),
          ),
        ]),
        const SizedBox(height: 9),
        Text(poll.question, style: AppText.bodyStrong.copyWith(fontSize: 12.8)),
        const SizedBox(height: 10),
        for (var i = 0; i < poll.options.length; i++) ...[
          _PollOption(
            label: poll.options[i],
            pct: _pct[i],
            voted: voted,
            selected: vote == i,
            onTap: () => onVote(i),
          ),
          if (i < poll.options.length - 1) const SizedBox(height: 7),
        ],
      ]),
    );
  }
}

class _PollOption extends StatelessWidget {
  const _PollOption({
    required this.label,
    required this.pct,
    required this.voted,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final int pct;
  final bool voted;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: voted ? null : onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Stack(children: [
            if (voted)
              Positioned.fill(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct / 100),
                  duration: const Duration(milliseconds: 520),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, _) => FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    child: Container(color: selected ? AppColors.primarySoft : const Color(0xFFF1EDF9)),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              child: Row(children: [
                Icon(
                  voted
                      ? (selected ? Icons.check_circle_rounded : Icons.circle_outlined)
                      : Icons.radio_button_unchecked_rounded,
                  size: 15,
                  color: selected ? AppColors.primary : AppColors.gray,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppFonts.ui,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 11.6,
                      color: AppColors.text,
                    ),
                  ),
                ),
                if (voted)
                  Text(
                    '$pct%',
                    style: const TextStyle(
                      fontFamily: AppFonts.ui,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.3,
                      color: AppColors.primaryDark,
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  const _PostAction({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w600, fontSize: 10.2, color: color),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guías
// ─────────────────────────────────────────────────────────────────────────────

class _GuideCarousel extends StatelessWidget {
  const _GuideCarousel({required this.onOpen});
  final ValueChanged<_Guide> onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _guides.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _GuideMiniCard(guide: _guides[i], onTap: () => onOpen(_guides[i])),
      ),
    );
  }
}

class _GuideMiniCard extends StatelessWidget {
  const _GuideMiniCard({required this.guide, required this.onTap});
  final _Guide guide;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 188,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.border, width: 0.8),
              boxShadow: AppShadows.card,
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: guide.colors,
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(guide.icon, size: 17, color: Colors.white),
                ),
                const Spacer(),
                const Text(
                  '4 min',
                  style: TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 9.3, color: AppColors.gray),
                ),
              ]),
              const SizedBox(height: 9),
              Text(guide.tag, style: AppText.label.copyWith(fontSize: 8.3, color: AppColors.primary, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  guide.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong.copyWith(fontSize: 13, height: 1.24),
                ),
              ),
              const SizedBox(height: 5),
              Row(children: [
                const Text(
                  'Leer guía',
                  style: TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 10.3, color: AppColors.primary),
                ),
                const SizedBox(width: 3),
                const Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.primary),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Encuentros y espacios
// ─────────────────────────────────────────────────────────────────────────────

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.attending, required this.onToggle});
  final _Event event;
  final bool attending;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Row(children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: event.colors,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.soft,
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(
              event.month,
              style: const TextStyle(
                fontFamily: AppFonts.ui,
                fontWeight: FontWeight.w800,
                fontSize: 8.3,
                letterSpacing: 1.1,
                color: Colors.white70,
              ),
            ),
            Text(
              event.day,
              style: const TextStyle(
                fontFamily: AppFonts.title,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                height: 1.05,
                color: Colors.white,
              ),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              event.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodyStrong.copyWith(fontSize: 13.1),
            ),
            const SizedBox(height: 3),
            Text(
              '${event.place} · ${event.time}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(fontSize: 10.6),
            ),
            const SizedBox(height: 6),
            Row(children: [
              const _MiniAvatars(),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  event.people,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: AppFonts.ui, fontSize: 9.6, color: AppColors.gray),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        _AttendButton(attending: attending, onTap: onToggle),
      ]),
    );
  }
}

class _MiniAvatars extends StatelessWidget {
  const _MiniAvatars();

  @override
  Widget build(BuildContext context) {
    const colors = [Color(0xFF765AD0), Color(0xFF3D9970), Color(0xFF3D7EC9)];
    return SizedBox(
      width: 42,
      height: 20,
      child: Stack(children: [
        for (var i = 0; i < colors.length; i++)
          Positioned(
            left: i * 11.0,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: colors[i],
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
            ),
          ),
      ]),
    );
  }
}

class _AttendButton extends StatelessWidget {
  const _AttendButton({required this.attending, required this.onTap});
  final bool attending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: attending ? AppColors.primary : AppColors.primaryMist,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            attending ? 'Asistiré' : 'Asistir',
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontWeight: FontWeight.w700,
              fontSize: 10.2,
              color: attending ? Colors.white : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpacesGrid extends StatelessWidget {
  const _SpacesGrid({required this.joined, required this.onToggle});
  final Set<String> joined;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    Widget cell(_Space space) => Expanded(
          child: SizedBox(
            height: 126,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.card,
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: space.colors,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(space.icon, size: 16, color: Colors.white),
                  ),
                  const Spacer(),
                  _JoinChip(
                    joined: joined.contains(space.name),
                    onTap: () => onToggle(space.name),
                  ),
                ]),
                const Spacer(),
                Text(
                  space.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong.copyWith(fontSize: 12.4),
                ),
                const SizedBox(height: 2),
                Text(
                  space.members,
                  style: const TextStyle(fontFamily: AppFonts.ui, fontSize: 9.6, color: AppColors.gray),
                ),
              ]),
            ),
          ),
        );

    return Column(children: [
      Row(children: [
        cell(_spaces[0]),
        const SizedBox(width: 10),
        cell(_spaces[1]),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        cell(_spaces[2]),
        const SizedBox(width: 10),
        cell(_spaces[3]),
      ]),
    ]);
  }
}

class _JoinChip extends StatelessWidget {
  const _JoinChip({required this.joined, required this.onTap});
  final bool joined;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: joined ? AppColors.primary : AppColors.primaryMist,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            joined ? 'Unida' : 'Unirme',
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontWeight: FontWeight.w700,
              fontSize: 9.2,
              color: joined ? Colors.white : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

class _GuidelinesCard extends StatelessWidget {
  const _GuidelinesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.primaryMist,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Cuidamos esta comunidad',
              style: TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.text),
            ),
            const SizedBox(height: 3),
            Text(
              'Sé respetuosa, cuida la privacidad y no compartas datos de otras personas sin permiso.',
              style: AppText.caption.copyWith(fontSize: 10.7, height: 1.4),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.bolt_rounded, color: AppColors.alertRed, size: 17),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Si hay peligro ahora, no esperes a leer',
              style: TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 11.8, color: AppColors.text),
            ),
          ),
        ]),
        const SizedBox(height: 9),
        const EmergencyLinks(),
      ]),
    );
  }
}

class _LumaiRow extends StatelessWidget {
  const _LumaiRow({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
            boxShadow: AppShadows.soft,
          ),
          child: Row(children: [
            Image.asset('assets/images/luma_hola.png', height: 52),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text(
                  '¿Prefieres preguntarlo en privado?',
                  style: TextStyle(
                    fontFamily: AppFonts.ui,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.3,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'LumAI te orienta sin juicios, cuando quieras.',
                  style: AppText.caption.copyWith(fontSize: 10.6),
                ),
              ]),
            ),
            const SizedBox(width: 6),
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: AppColors.primaryMist, shape: BoxShape.circle),
              child: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hojas: publicar, comentar y perfil
// ─────────────────────────────────────────────────────────────────────────────

class _ComposerSheet extends StatefulWidget {
  const _ComposerSheet({required this.initialTopic});
  final String initialTopic;
  @override
  State<_ComposerSheet> createState() => _ComposerSheetState();
}

class _ComposerSheetState extends State<_ComposerSheet> {
  final _ctl = TextEditingController();
  late String _topic = widget.initialTopic;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _publish() {
    final text = _ctl.text.trim();
    if (text.isEmpty) return;
    Navigator.of(context).pop(_Post(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      author: AppState.instance.nombre,
      role: 'Aliada',
      time: 'Ahora',
      topic: _topic,
      text: text,
      color: AppColors.primary,
      likes: 0,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height - bottom - 24;
    final canPublish = _ctl.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(color: AppColors.grayLight, borderRadius: BorderRadius.circular(3)),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Avatar(name: AppState.instance.nombre, size: 42, color: AppColors.primary, ring: AppColors.primaryMist),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(AppState.instance.nombre, style: AppText.bodyStrong.copyWith(fontSize: 13.4)),
                    const Text(
                      'Comparte con la comunidad',
                      style: TextStyle(fontFamily: AppFonts.ui, fontSize: 10.4, color: AppColors.gray),
                    ),
                  ]),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(backgroundColor: AppColors.primaryMist, foregroundColor: AppColors.textSoft),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _ctl,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                maxLength: 280,
                onChanged: (_) => setState(() {}),
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: '¿Qué quieres compartir? Una duda, un consejo o algo que te pasó…',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              const Text('TEMA', style: AppText.label),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in const ['Testimonio', 'Consejo', 'Pregunta'])
                  _PickChip(label: t, selected: _topic == t, onTap: () => setState(() => _topic = t)),
              ]),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: AppColors.primaryMist, borderRadius: BorderRadius.circular(AppRadius.sm)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.primary),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Cuida tu privacidad: no incluyas nombres, capturas ni datos de otras personas.',
                      style: AppText.caption.copyWith(fontSize: 10.7, height: 1.4),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 50,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: canPublish ? AppColors.primaryGradient : null,
                    color: canPublish ? null : AppColors.grayLight,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: canPublish ? AppShadows.floating : null,
                  ),
                  child: TextButton(
                    onPressed: canPublish ? _publish : null,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      disabledForegroundColor: AppColors.gray,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      textStyle: const TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 13.4),
                    ),
                    child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.send_rounded, size: 17),
                      SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          'Publicar en la comunidad',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PickChip extends StatelessWidget {
  const _PickChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.ui,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              color: selected ? Colors.white : AppColors.textSoft,
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.post, required this.comments, required this.onAdd});
  final _Post post;
  final List<_Comment> comments;
  final ValueChanged<String> onAdd;
  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  late final List<_Comment> _items = List<_Comment>.of(widget.comments);
  final _ctl = TextEditingController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _ctl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _items.add(_Comment(AppState.instance.nombre, text, AppColors.primary));
    });
    widget.onAdd(text);
    _ctl.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final maxH = MediaQuery.sizeOf(context).height - bottom - 24;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 10),
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(color: AppColors.grayLight, borderRadius: BorderRadius.circular(3)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Comentarios', style: AppText.h3),
                    Text(
                      '${_items.length} en esta publicación',
                      style: AppText.caption.copyWith(fontSize: 10.6),
                    ),
                  ]),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(backgroundColor: AppColors.primaryMist, foregroundColor: AppColors.textSoft),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ]),
            ),
            const Divider(height: 1, color: AppColors.border),
            Flexible(
              child: _items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 24),
                      child: Text(
                        'Todavía no hay comentarios. Sé la primera en responder con cuidado.',
                        textAlign: TextAlign.center,
                        style: AppText.caption.copyWith(fontSize: 11.4),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _CommentRow(comment: _items[i]),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _ctl,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(hintText: 'Escribe un comentario…', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: AppColors.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _send,
                    child: const SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(Icons.send_rounded, color: Colors.white, size: 19),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});
  final _Comment comment;

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Avatar(name: comment.author, size: 32, color: comment.color, ring: AppColors.primaryMist),
      const SizedBox(width: 9),
      Expanded(
        child: Container(
          padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
          decoration: BoxDecoration(color: AppColors.backgroundSoft, borderRadius: BorderRadius.circular(13)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(comment.author, style: AppText.bodyStrong.copyWith(fontSize: 11.7)),
            const SizedBox(height: 2),
            Text(comment.text, style: AppText.body.copyWith(fontSize: 12, height: 1.4)),
          ]),
        ),
      ),
    ]);
  }
}

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({required this.person, required this.initiallyFollowing, required this.onToggle});
  final _Person person;
  final bool initiallyFollowing;
  final ValueChanged<bool> onToggle;
  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  late bool _following = widget.initiallyFollowing;

  @override
  Widget build(BuildContext context) {
    final p = widget.person;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: AppColors.grayLight, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [p.color, p.color.withValues(alpha: 0.55)]),
                ),
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
                  child: Avatar(name: p.name, size: 60, color: p.color, ring: Colors.transparent),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.name, style: AppText.h2.copyWith(fontSize: 19)),
                  const SizedBox(height: 2),
                  Text(p.role, style: AppText.caption.copyWith(fontSize: 11.4)),
                ]),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(backgroundColor: AppColors.primaryMist, foregroundColor: AppColors.textSoft),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ]),
            const SizedBox(height: 14),
            Text(p.bio, style: AppText.body.copyWith(fontSize: 12.7, color: AppColors.textSoft)),
            const SizedBox(height: 16),
            Row(children: [
              _Stat(value: p.stats, label: 'en la red'),
              const SizedBox(width: 16),
              const _Stat(value: '12', label: 'publicaciones'),
              const SizedBox(width: 16),
              const _Stat(value: '4', label: 'talleres'),
            ]),
            const SizedBox(height: 18),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: _following ? null : AppColors.primaryGradient,
                  color: _following ? AppColors.primaryMist : null,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: TextButton(
                  onPressed: () {
                    setState(() => _following = !_following);
                    widget.onToggle(_following);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: _following ? AppColors.primary : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    textStyle: const TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  child: Text(_following ? 'Siguiendo · Aliada de tu red' : 'Seguir a ${p.name.split(' ').first}'),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: AppText.h3.copyWith(fontSize: 15)),
      Text(label, style: const TextStyle(fontFamily: AppFonts.ui, fontSize: 9.4, color: AppColors.gray)),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hoja de lectura
// ─────────────────────────────────────────────────────────────────────────────

class _GuideSheet extends StatelessWidget {
  const _GuideSheet({required this.guide, required this.onAskLumai});
  final _Guide guide;
  final VoidCallback onAskLumai;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 10),
        Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(color: AppColors.grayLight, borderRadius: BorderRadius.circular(3)),
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: guide.colors,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Icon(guide.icon, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    guide.tag,
                    style: AppText.label.copyWith(fontSize: 9, color: AppColors.primary),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primaryMist,
                    foregroundColor: AppColors.textSoft,
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ]),
              const SizedBox(height: 14),
              Text(guide.title, style: AppText.h1.copyWith(fontSize: 24)),
              const SizedBox(height: 10),
              Text(guide.body, style: AppText.body.copyWith(fontSize: 13.6, color: AppColors.textSoft)),
              const SizedBox(height: 16),
              for (final b in guide.bullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 20,
                      height: 20,
                      margin: const EdgeInsets.only(top: 1),
                      decoration: const BoxDecoration(color: AppColors.primaryMist, shape: BoxShape.circle),
                      child: const Icon(Icons.check_rounded, size: 13, color: AppColors.primary),
                    ),
                    const SizedBox(width: 9),
                    Expanded(child: Text(b, style: AppText.body.copyWith(fontSize: 12.9, height: 1.45))),
                  ]),
                ),
              if (guide.note != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMist,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        guide.note!,
                        style: AppText.caption.copyWith(fontSize: 11.4, height: 1.45),
                      ),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                height: 48,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.limeGradient,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    boxShadow: AppShadows.limeGlow,
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.limeText,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      textStyle: const TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w800, fontSize: 13.3),
                    ),
                    child: const Text('Listo, gracias'),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onAskLumai();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(fontFamily: AppFonts.ui, fontWeight: FontWeight.w700, fontSize: 11.4),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.auto_awesome_outlined, size: 15),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Prefiero preguntarle a LumAI',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ),
              ),
              Center(
                child: Text(
                  'Puedes cerrar esta guía en cualquier momento. No tienes que decidir ahora.',
                  textAlign: TextAlign.center,
                  style: AppText.caption.copyWith(fontSize: 10.3),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Datos de la comunidad
// ─────────────────────────────────────────────────────────────────────────────

class _Post {
  const _Post({
    required this.id,
    required this.author,
    required this.role,
    required this.time,
    required this.topic,
    required this.text,
    required this.color,
    this.official = false,
    this.quote,
    this.poll,
    this.likes = 0,
  });
  final String id;
  final String author;
  final String role;
  final String time;
  final String topic;
  final String text;
  final Color color;
  final bool official;
  final String? quote;
  final _Poll? poll;
  final int likes;
}

class _Poll {
  const _Poll(this.question, this.options);
  final String question;
  final List<String> options;
}

class _Comment {
  const _Comment(this.author, this.text, this.color);
  final String author;
  final String text;
  final Color color;
}

class _Person {
  const _Person(this.name, this.color, this.role, this.bio, this.stats);
  final String name;
  final Color color;
  final String role;
  final String bio;
  final String stats;
}

class _Event {
  const _Event({
    required this.title,
    required this.place,
    required this.time,
    required this.month,
    required this.day,
    required this.people,
    required this.colors,
  });
  final String title;
  final String place;
  final String time;
  final String month;
  final String day;
  final String people;
  final List<Color> colors;
}

class _Space {
  const _Space(this.name, this.members, this.icon, this.colors);
  final String name;
  final String members;
  final IconData icon;
  final List<Color> colors;
}

class _Guide {
  const _Guide({
    required this.tag,
    required this.title,
    required this.icon,
    required this.colors,
    required this.body,
    required this.bullets,
    this.note,
  });
  final String tag;
  final String title;
  final IconData icon;
  final List<Color> colors;
  final String body;
  final List<String> bullets;
  final String? note;
}

const _people = <_Person>[
  _Person(
    'Julia Linarez',
    Color(0xFF765AD0),
    'Mentora · 6.º ciclo',
    'Mentora de ciclos superiores. Comparte lo que aprendió para que otras no tengan que empezar de cero.',
    '128',
  ),
  _Person(
    'Andrea Salas',
    Color(0xFF3D9970),
    'Aliada · 3.º ciclo',
    'Acompaña a compañeras a Bienestar y cree que cuidar también es escuchar sin juzgar.',
    '86',
  ),
  _Person(
    'Camila Rocca',
    Color(0xFF3D7EC9),
    'Aliada · 4.º ciclo',
    'Le interesa el acoso digital y cómo cuidar nuestra privacidad en redes.',
    '64',
  ),
  _Person(
    'Vale Ríos',
    Color(0xFFB0763F),
    'Aliada · 2.º ciclo',
    'Estudiante de segundo ciclo. Busca talleres y espacios para conocer a otras aliadas.',
    '42',
  ),
];

const _demoPosts = <_Post>[
  _Post(
    id: 'julia',
    author: 'Julia Linarez',
    role: 'Mentora · 6.º ciclo',
    time: 'hace 2 h',
    topic: 'Testimonio',
    color: Color(0xFF765AD0),
    likes: 24,
    text:
        'Durante mucho tiempo pensé que lo que me pasaba “no era para tanto”. Nadie me dijo que insistir después de un no también es acoso. Hoy sé que no necesitaba tener todas las palabras para pedir ayuda.',
    quote: 'No es tu culpa que alguien no respete un no.',
  ),
  _Post(
    id: 'colectivo',
    author: 'Colectivo Aliadas',
    role: 'Cuenta oficial · Comunidad',
    time: 'hace 4 h',
    topic: 'Pregunta',
    color: Color(0xFF6E4FD8),
    official: true,
    likes: 12,
    text:
        'Estamos armando el próximo taller y queremos que salga de lo que ustedes necesitan. ¿Qué tema te gustaría trabajar primero?',
    poll: _Poll('¿Qué tema quieres en el próximo taller?', [
      'Límites y consentimiento',
      'Acoso digital',
      'Derechos y ruta',
    ]),
  ),
  _Post(
    id: 'andrea',
    author: 'Andrea Salas',
    role: 'Aliada · 3.º ciclo',
    time: 'hace 6 h',
    topic: 'Consejo',
    color: Color(0xFF3D9970),
    likes: 41,
    text:
        'Ayer acompañé a una compañera a Bienestar. No tenía que saber qué decir: bastó con estar, escucharla y decirle “te acompaño”. Si alguien te cuenta algo, no la hagas repetir mil veces la historia.',
  ),
  _Post(
    id: 'camila',
    author: 'Camila Rocca',
    role: 'Aliada · 4.º ciclo',
    time: 'ayer',
    topic: 'Consejo',
    color: Color(0xFF3D7EC9),
    likes: 18,
    text:
        'Si te está pasando por redes, guarda evidencia antes de bloquear: capturas con fecha, el usuario y el chat completo. No borres la conversación. Y cuéntale a alguien de confianza lo que está pasando.',
  ),
];

const _events = <_Event>[
  _Event(
    title: 'Taller contra el acoso',
    place: 'Julia Aguirre · Aula B-204',
    time: '7:00 pm',
    month: 'JUN',
    day: '12',
    people: '12 asistirán',
    colors: [Color(0xFF8262EC), Color(0xFF5232BB)],
  ),
  _Event(
    title: 'Grupo de apoyo',
    place: 'UPC · Espacio de encuentro',
    time: '8:00 pm',
    month: 'JUN',
    day: '12',
    people: '8 asistirán',
    colors: [Color(0xFF3D7EC9), Color(0xFF245FA6)],
  ),
];

const _spaces = <_Space>[
  _Space('Mentoras', '128 aliadas', Icons.school_outlined, [Color(0xFF8262EC), Color(0xFF5232BB)]),
  _Space('Primer ciclo', '86 aliadas', Icons.auto_awesome_outlined, [Color(0xFF2FA37C), Color(0xFF1D7A5B)]),
  _Space('Varones aliados', '54 aliados', Icons.groups_2_outlined, [Color(0xFF3D7EC9), Color(0xFF245FA6)]),
  _Space('Autocuidado', '73 aliadas', Icons.self_improvement_rounded, [Color(0xFFB0763F), Color(0xFF7E5327)]),
];

const _guides = <_Guide>[
  _Guide(
    tag: 'RECONOCER',
    title: '¿Esto cuenta como acoso?',
    icon: Icons.psychology_alt_outlined,
    colors: [Color(0xFF8262EC), Color(0xFF5232BB)],
    body:
        'No siempre es fácil ponerle nombre a lo que pasa. Si una conducta te incomoda, te persigue o te hace sentir insegura, merece atención, aunque todavía no sepas cómo llamarla.',
    bullets: [
      'Comentarios sexuales sobre tu cuerpo o tu forma de vestir.',
      'Mensajes insistentes después de que dijiste que no.',
      'Acercamientos, toques o abrazos sin consentimiento.',
      'Fotos o contenido íntimo enviados sin que los pidieras.',
      'Difundir tus conversaciones, datos o imágenes sin permiso.',
    ],
    note:
        'Esta guía es orientativa. No determina si hubo hostigamiento: eso lo evalúa una persona especializada y el protocolo de tu universidad.',
  ),
  _Guide(
    tag: 'LÍMITES',
    title: 'Consentimiento y límites',
    icon: Icons.pan_tool_alt_outlined,
    colors: [Color(0xFF2FA37C), Color(0xFF1D7A5B)],
    body:
        'El consentimiento es un sí libre, informado y que se puede retirar en cualquier momento. Un «no» dicho una vez sigue siendo un «no».',
    bullets: [
      'Puedes cambiar de opinión, incluso si ya habías aceptado.',
      'Un regalo, una salida o una relación previa no implican consentimiento.',
      'El silencio, la duda o la incomodidad no son un sí.',
      'Tu ropa, tus horarios y tus redes no son una invitación.',
    ],
    note: 'Si alguien no respeta tu límite, no es tu culpa. Puedes pedir ayuda sin tener que justificarte.',
  ),
  _Guide(
    tag: 'DIGITAL',
    title: 'Acoso en línea',
    icon: Icons.forum_outlined,
    colors: [Color(0xFF3D7EC9), Color(0xFF245FA6)],
    body:
        'El acoso también ocurre por WhatsApp, redes sociales y plataformas de estudio. No hace falta que sea constante para afectarte.',
    bullets: [
      'Mensajes repetidos o desde cuentas nuevas después de un bloqueo.',
      'Presión para compartir tu número, dirección o redes.',
      'Capturas o fotos tuyas compartidas sin permiso.',
      'Vigilancia de tus horarios, ubicación o publicaciones.',
      'Comentarios sexistas en grupos de la facultad.',
    ],
    note: 'Puedes guardar evidencia, silenciar, bloquear y pedir compañía. No tienes que responder.',
  ),
  _Guide(
    tag: 'DERECHOS',
    title: 'Tus derechos',
    icon: Icons.gavel_rounded,
    colors: [Color(0xFF7CB342), Color(0xFF558B2F)],
    body:
        'En el Perú, la Ley N.° 27942 y su reglamento obligan a las universidades a prevenir, atender y sancionar el hostigamiento sexual.',
    bullets: [
      'Recibir orientación sin ser revictimizada.',
      'Que tu caso se trate con confidencialidad.',
      'Contar con medidas de protección mientras se evalúa.',
      'Usar los canales institucionales: Bienestar, Defensoría u oficina de Igualdad de Género.',
    ],
    note:
        'Aliada se integra al protocolo de tu universidad. No reemplaza a la autoridad competente ni decide por ti.',
  ),
];

