import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/storage/auth_storage.dart';
import '../../core/theme/design_tokens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _signedIn = false;
  @override void initState() { super.initState(); _loadSession(); }
  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _signedIn = AuthStorage(prefs).isLoggedIn);
  }
  @override
  Widget build(BuildContext context) => CustomScrollView(
    physics: const BouncingScrollPhysics(),
    slivers: [
      SliverToBoxAdapter(child: _TopHeader(signedIn: _signedIn)),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 34),
        sliver: SliverList(
          delegate: SliverChildListDelegate([
            const SizedBox(height: 14),
            _SearchCard(onTap: () => context.push('/materials')),
            const SizedBox(height: 20),
            _SectionTitle(title: 'الوصول السريع', action: 'حسابي', onTap: () => context.push('/student')),
            const SizedBox(height: 10),
            const _QuickActions(),
            const SizedBox(height: 22),
            _SectionTitle(title: 'مستواك الدراسي', action: 'ملفي', onTap: () => context.push('/student')),
            const SizedBox(height: 10),
            _ProgressCard(signedIn: _signedIn),
            const SizedBox(height: 22),
            _SectionTitle(title: 'آخر المستجدات', action: 'عرض الكل', onTap: () => context.push('/news')),
            const SizedBox(height: 10),
            const _Updates(),
            const SizedBox(height: 22),
            const _EinoCard(),
            const SizedBox(height: 22),
            const _ServicesBanner(),
          ]),
        ),
      ),
    ],
  );
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.signedIn});
  final bool signedIn;
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(begin: AlignmentDirectional.topStart, end: AlignmentDirectional.bottomEnd, colors: [AppColors.navy, Color(0xFF183F5D)]),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        child: Column(children: [
          Row(children: [
            Image.asset('assets/images/trinex_logo.png', width: 128, fit: BoxFit.contain),
            const Spacer(),
            _HeaderButton(icon: Icons.notifications_none_rounded, onTap: () => context.push('/notifications')),
            const SizedBox(width: 8),
            _HeaderButton(icon: Icons.person_outline_rounded, onTap: () => context.push('/student')),
          ]),
          const SizedBox(height: 18),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(signedIn ? 'مرحبًا بك من جديد 👋' : 'مرحبًا بك في TRINEX 👋', style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(signedIn ? 'جاهز تكمل طريقك نحو مستقبل أفضل؟' : 'منصة هندسة وعمارة وتقنية، مصممة لرحلتك الجامعية.', style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 13.5, height: 1.45)),
            ])),
            const SizedBox(width: 12),
            Container(width: 54, height: 54, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .09), borderRadius: BorderRadius.circular(17)), child: const Icon(Icons.architecture_rounded, color: AppColors.primary, size: 29)),
          ]),
          const SizedBox(height: 18),
          const Row(children: [
            Expanded(child: _MiniHeaderStat(icon: Icons.menu_book_rounded, label: 'المواد')),
            SizedBox(width: 8),
            Expanded(child: _MiniHeaderStat(icon: Icons.calendar_month_rounded, label: 'الجدول')),
            SizedBox(width: 8),
            Expanded(child: _MiniHeaderStat(icon: Icons.auto_awesome_rounded, label: 'إينو')),
          ]),
        ]),
      ),
    ),
  );
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});
  final IconData icon; final VoidCallback onTap;
  @override Widget build(BuildContext context) => Material(color: Colors.white.withValues(alpha: .10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14), child: SizedBox(width: 43, height: 43, child: Icon(icon, color: Colors.white, size: 21))));
}
class _MiniHeaderStat extends StatelessWidget {
  const _MiniHeaderStat({required this.icon, required this.label});
  final IconData icon; final String label;
  @override Widget build(BuildContext context) => Container(height: 43, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .075), borderRadius: BorderRadius.circular(13)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: AppColors.primary, size: 18), const SizedBox(width: 6), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))]));
}
class _SearchCard extends StatelessWidget {
  const _SearchCard({required this.onTap}); final VoidCallback onTap;
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(height: 56, padding: const EdgeInsets.symmetric(horizontal: 15), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: .5))), child: Row(children: [Icon(Icons.search_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant), const SizedBox(width: 10), Expanded(child: Text('ابحث عن المواد، المقررات والخدمات...', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))), Container(width: 35, height: 35, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .11), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 18))])));
}
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.action, required this.onTap}); final String title, action; final VoidCallback onTap;
  @override Widget build(BuildContext context) => Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)), TextButton(onPressed: onTap, child: Text(action))]);
}
class _QuickActions extends StatelessWidget {
  const _QuickActions();
  @override Widget build(BuildContext context) {
    const items = [(Icons.menu_book_rounded, 'المواد', 'محاضرات وملفات', '/materials'), (Icons.calendar_month_rounded, 'الجدول', 'حصصك القادمة', '/schedule'), (Icons.notifications_rounded, 'الإشعارات', 'آخر التنبيهات', '/notifications'), (Icons.storefront_rounded, 'المتجر', 'أدوات هندسية', '/market')];
    return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: items.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.58), itemBuilder: (context, i) { final x = items[i]; return _ActionCard(icon: x.$1, title: x.$2, subtitle: x.$3, onTap: () => context.push(x.$4), active: i == 0); });
  }
}
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap, this.active = false}); final IconData icon; final String title, subtitle; final VoidCallback onTap; final bool active;
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: .52))), child: Row(children: [Container(width: 44, height: 44, decoration: BoxDecoration(color: active ? AppColors.primary : AppColors.navy.withValues(alpha: .07), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: active ? Colors.white : AppColors.navy, size: 22)), const SizedBox(width: 10), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)]))])));
}
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.signedIn}); final bool signedIn;
  @override Widget build(BuildContext context) => InkWell(onTap: () => context.push(signedIn ? '/progress' : '/student'), borderRadius: BorderRadius.circular(22), child: Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: .52))), child: Column(children: [Row(children: [Container(width: 50, height: 50, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 27)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(signedIn ? 'مستوى الطالب' : 'ابدأ رحلتك الدراسية', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const SizedBox(height: 4), Text(signedIn ? '850 / 1200 XP' : 'سجّل الدخول لفتح المواد والجدول وXP', style: Theme.of(context).textTheme.bodySmall)])), const Icon(Icons.chevron_left_rounded)]), const SizedBox(height: 16), ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: signedIn ? .70 : 0, minHeight: 8, backgroundColor: AppColors.navy.withValues(alpha: .08), valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary))), const SizedBox(height: 9), Row(children: [Text(signedIn ? 'المستوى 8' : 'الزائر', style: Theme.of(context).textTheme.labelMedium), const Spacer(), Text(signedIn ? '70%' : '—', style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900))])])));
}
class _Updates extends StatelessWidget {
  const _Updates();
  @override Widget build(BuildContext context) => SizedBox(height: 128, child: ListView(scrollDirection: Axis.horizontal, physics: const BouncingScrollPhysics(), children: const [_UpdateCard(icon: Icons.campaign_rounded, title: 'إعلان عام', subtitle: 'آخر تنبيهات الرابطة', route: '/announcements'), SizedBox(width: 10), _UpdateCard(icon: Icons.article_rounded, title: 'مادة جديدة', subtitle: 'محتوى دراسي مضاف حديثًا', route: '/news'), SizedBox(width: 10), _UpdateCard(icon: Icons.event_available_rounded, title: 'نشاط قادم', subtitle: 'فعاليات ومبادرات جديدة', route: '/activities')]));
}
class _UpdateCard extends StatelessWidget {
  const _UpdateCard({required this.icon, required this.title, required this.subtitle, required this.route}); final IconData icon; final String title, subtitle, route;
  @override Widget build(BuildContext context) => SizedBox(width: 238, child: InkWell(onTap: () => context.push(route), borderRadius: BorderRadius.circular(20), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: .52))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(width: 35, height: 35, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: .12), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: AppColors.primary, size: 18)), const Spacer(), const Icon(Icons.north_east_rounded, size: 17)]), const Spacer(), Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)]))));
}
class _EinoCard extends StatefulWidget { const _EinoCard(); @override State<_EinoCard> createState()=>_EinoCardState(); }
class _EinoCardState extends State<_EinoCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
  @override void dispose(){_c.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>InkWell(onTap:()=>context.push('/eino?from=home'),borderRadius:BorderRadius.circular(25),child:Container(height:220,clipBehavior:Clip.antiAlias,decoration:BoxDecoration(borderRadius:BorderRadius.circular(25),gradient:const LinearGradient(begin:AlignmentDirectional.topStart,end:AlignmentDirectional.bottomEnd,colors:[AppColors.navy,Color(0xFF173D5A)])),child:Stack(children:[const PositionedDirectional(top:-30,end:-20,child:_CircuitArt()),PositionedDirectional(bottom:-5,end:-10,child:AnimatedBuilder(animation:_c,builder:(context,child)=>Transform.translate(offset:Offset(0,-4*_c.value),child:child),child:Image.asset('assets/images/eino.png',height:205,fit:BoxFit.contain))),Padding(padding:const EdgeInsets.fromLTRB(18,18,150,18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Container(width:34,height:34,decoration:BoxDecoration(color:AppColors.primary,borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.auto_awesome_rounded,color:Colors.white,size:18)),const SizedBox(width:9),const Text('إينو',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900))]),const SizedBox(height:10),Text('مساعدك الذكي داخل TRINEX',style:TextStyle(color:Colors.white.withValues(alpha:.82),fontSize:13.5,height:1.4)),const Spacer(),const Text('اسأليها عن الدراسة، المواد، الجدول أو التطبيق.',style:TextStyle(color:Colors.white70,fontSize:12,height:1.4)),const SizedBox(height:12),Container(height:40,padding:const EdgeInsets.symmetric(horizontal:15),decoration:BoxDecoration(color:AppColors.primary,borderRadius:BorderRadius.circular(13)),child:const Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.chat_bubble_outline_rounded,color:Colors.white,size:17),SizedBox(width:7),Text('ابدأ المحادثة',style:TextStyle(color:Colors.white,fontWeight:FontWeight.w800))]))]))])));
}
class _CircuitArt extends StatelessWidget{const _CircuitArt();@override Widget build(BuildContext context)=>CustomPaint(size:const Size(180,180),painter:_CircuitPainter());}
class _CircuitPainter extends CustomPainter{ @override void paint(Canvas c,Size s){final p=Paint()..color=AppColors.primary.withValues(alpha:.45)..style=PaintingStyle.stroke..strokeWidth=2.2..strokeCap=StrokeCap.round;final path=Path()..moveTo(20,10)..lineTo(20,55)..lineTo(62,55)..lineTo(85,82)..lineTo(85,125)..moveTo(62,55)..lineTo(118,55)..lineTo(145,28);c.drawPath(path,p);for(final q in [const Offset(20,55),const Offset(85,82),const Offset(85,125),const Offset(118,55),const Offset(145,28)]){c.drawCircle(q,4,p);}}@override bool shouldRepaint(covariant _CircuitPainter oldDelegate)=>false;}
class _ServicesBanner extends StatelessWidget{const _ServicesBanner();@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(17),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surface,borderRadius:BorderRadius.circular(22),border:Border.all(color:Theme.of(context).colorScheme.outline.withValues(alpha:.52))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('كل ما تحتاجه',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:13),const Wrap(spacing:8,runSpacing:8,children:[_ServiceChip(icon:Icons.emoji_events_rounded,text:'الإنجازات',route:'/achievements'),_ServiceChip(icon:Icons.favorite_rounded,text:'المفضلة',route:'/favorites'),_ServiceChip(icon:Icons.history_rounded,text:'الأخيرة',route:'/recent'),_ServiceChip(icon:Icons.settings_rounded,text:'الإعدادات',route:'/settings')]) ]));}
class _ServiceChip extends StatelessWidget{const _ServiceChip({required this.icon,required this.text,required this.route});final IconData icon;final String text,route;@override Widget build(BuildContext context)=>ActionChip(avatar:Icon(icon,size:17,color:AppColors.primary),label:Text(text),onPressed:()=>context.push(route));}
