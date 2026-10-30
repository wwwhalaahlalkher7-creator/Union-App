part of 'content_detail_screen.dart';

class _Gallery extends StatelessWidget {
  const _Gallery({required this.images});
  final List<String> images;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.network(
            images.first,
            width: double.infinity,
            fit: BoxFit.contain,
            cacheWidth: (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round(),
            filterQuality: FilterQuality.low,
            errorBuilder: (_, _, _) => const _Fallback(label: '', icon: Icons.broken_image_outlined),
          ),
        ),
        if (images.length > 1)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 10),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
              ),
              itemCount: images.length - 1,
              itemBuilder: (context, index) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  images[index + 1],
                  fit: BoxFit.cover,
                  cacheWidth: (MediaQuery.sizeOf(context).width / 3 * MediaQuery.devicePixelRatioOf(context)).round(),
                  filterQuality: FilterQuality.low,
                  errorBuilder: (_, _, _) => Container(
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 190,
      color: cs.surfaceContainerHigh,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: cs.primary),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: cs.primary)),
            ],
          ],
        ),
      ),
    );
  }
}

