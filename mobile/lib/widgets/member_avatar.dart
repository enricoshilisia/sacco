import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/session.dart';
import '../theme.dart';
import 'common.dart';

/// The logged-in person's photo, or their initials on the sunrise gradient
/// when there's no photo (or it fails to load).
class MemberAvatar extends StatelessWidget {
  final double size;
  const MemberAvatar({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final first = session.member?.firstName ?? session.profile?.firstName ?? '';
    final last = session.member?.lastName ?? session.profile?.lastName ?? '';
    final initials = '${first.isEmpty ? '' : first[0]}${last.isEmpty ? '' : last[0]}'.toUpperCase();
    final photo = session.member?.photo;

    final fallback = Center(
      child: Text(initials.isEmpty ? '?' : initials,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: InukaColors.sunrise,
        border: Border.all(color: Colors.white, width: size > 60 ? 3 : 2),
        boxShadow: [BoxShadow(color: InukaColors.orange.withValues(alpha: 0.35), blurRadius: size * 0.25)],
      ),
      child: ClipOval(
        child: photo == null || photo.isEmpty
            ? fallback
            : Image.network(
                photo,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (context, child, progress) => progress == null ? child : fallback,
              ),
      ),
    );
  }
}

/// Lets a member choose a photo from the camera or gallery and uploads it.
/// The phone shrinks it to 1024px JPEG first (so even 50MP or HEIC shots
/// upload quickly); the server accepts any image format as a fallback.
Future<void> changeProfilePhoto(BuildContext context) async {
  final l10n = context.l10n;
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.photo_camera_outlined),
          title: Text(l10n.photoTake),
          onTap: () => Navigator.pop(context, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library_outlined),
          title: Text(l10n.photoChoose),
          onTap: () => Navigator.pop(context, ImageSource.gallery),
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
  if (source == null || !context.mounted) return;

  final XFile? picked;
  try {
    picked = await ImagePicker().pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
  } catch (e) {
    if (context.mounted) showSnack(context, l10n.photoPickFailed, error: true);
    return;
  }
  if (picked == null || !context.mounted) return;

  final session = context.read<Session>();
  showSnack(context, l10n.photoUploading);
  try {
    await session.api!.uploadMyPhoto(picked.path);
    await session.reloadMember();
    if (context.mounted) showSnack(context, l10n.photoUpdated);
  } catch (e) {
    if (context.mounted) showSnack(context, errorText(context, e), error: true);
  }
}
