import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/models/schedule_item.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../core/theme/design_tokens.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override State<ScheduleScreen> createState()=>_ScheduleScreenState();
}
class _ScheduleScreenState extends State<ScheduleScreen> {
  ApiClient? _client; ScheduleRepository? _repo; Future<ScheduleData>? _future;
  List<Map<String,dynamic>> _semesters=[]; String? _semesterId; int? _selectedDay;
  @override void initState(){super.initState();_init();}
  @override void dispose(){_client?.dispose();super.dispose();}
  Future<void> _init() async { try{_client=await AuthenticatedClient.create();_repo=ScheduleRepository(_client!);_semesters=await _repo!.semesters();_future=_repo!.getSchedule();if(mounted)setState((){});}catch(e){if(mounted)setState(()=>_future=Future.error(e));} }
  Future<void> _reload() async { final r=_repo;if(r==null)return;setState(()=>_future=r.getSchedule(semesterId:_semesterId)); }
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Theme.of(context).colorScheme.surfaceContainerLowest,body:CustomScrollView(slivers:[
    SliverToBoxAdapter(child:_Header(onRefresh:_reload)),
    SliverPadding(padding:const EdgeInsets.fromLTRB(16,14,16,120),sliver:SliverList(delegate:SliverChildListDelegate([
      if(_semesters.isNotEmpty)DropdownButtonFormField<String>(value:_semesterId,decoration:const InputDecoration(labelText:'الفصل الدراسي',prefixIcon:Icon(Icons.calendar_month_rounded)),items:_semesters.map((s)=>DropdownMenuItem(value:s['id']?.toString(),child:Text((s['name_ar']??s['name']??'الفصل').toString()))).toList(),onChanged:(v){_semesterId=v;_selectedDay=null;_reload();}),
      const SizedBox(height:14),
      FutureBuilder<ScheduleData>(future:_future,builder:(context,s){
        if(s.connectionState==ConnectionState.waiting)return const Padding(padding:EdgeInsets.all(40),child:Center(child:CircularProgressIndicator()));
        if(s.hasError)return const _Message(text:'تعذر تحميل الجدول الدراسي.');
        final data=s.data!;
        final days=data.days.isEmpty?(data.items.map((e)=>e.dayOfWeek).toSet().toList()..sort()):data.days;
        final day=_selectedDay??(days.isEmpty?null:days.first);
        final items=data.items.where((e)=>day==null||e.dayOfWeek==day).toList();
        return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          _ContextCard(data:data),const SizedBox(height:14),
          if(days.isNotEmpty)_Days(days:days,selected:day,onChanged:(v)=>setState(()=>_selectedDay=v)),
          const SizedBox(height:16),
          if(items.isEmpty)const _Message(text:'لا توجد حصص في هذا اليوم.') else ...items.map((e)=>_ClassCard(item:e)),
        ]);
      }),
    ]))),
  ]));
}
class _Header extends StatelessWidget{const _Header({required this.onRefresh});final VoidCallback onRefresh;@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.fromLTRB(18,10,18,22),decoration:const BoxDecoration(gradient:LinearGradient(begin:AlignmentDirectional.topStart,end:AlignmentDirectional.bottomEnd,colors:[AppColors.navy,Color(0xFF173D5A)]),borderRadius:BorderRadius.vertical(bottom:Radius.circular(28))),child:SafeArea(bottom:false,child:Row(children:[Container(width:48,height:48,decoration:BoxDecoration(color:Colors.white10,borderRadius:BorderRadius.circular(15)),child:const Icon(Icons.calendar_month_rounded,color:AppColors.primary)),const SizedBox(width:12),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('الجدول الدراسي',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),SizedBox(height:3),Text('خطتك الأسبوعية في لمحة',style:TextStyle(color:Colors.white70,fontSize:12))])),IconButton(onPressed:onRefresh,icon:const Icon(Icons.refresh_rounded,color:Colors.white))])));}
class _ContextCard extends StatelessWidget{const _ContextCard({required this.data});final ScheduleData data;@override Widget build(BuildContext context){final dept=(data.department?['name_ar']??data.department?['name']??'تخصصك').toString();final sem=(data.semester?['name_ar']??data.semester?['name']??'الفصل الحالي').toString();return Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:AppColors.navy,borderRadius:BorderRadius.circular(20)),child:Row(children:[Container(width:42,height:42,decoration:BoxDecoration(color:Colors.white10,borderRadius:BorderRadius.circular(13)),child:const Icon(Icons.school_rounded,color:AppColors.primary)),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(dept,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(sem,style:const TextStyle(color:Colors.white70,fontSize:12))]))]));}}
class _Days extends StatelessWidget{const _Days({required this.days,required this.selected,required this.onChanged});final List<int> days;final int? selected;final ValueChanged<int> onChanged;@override Widget build(BuildContext context)=>SizedBox(height:48,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:days.length,separatorBuilder:(_,_)=>const SizedBox(width:8),itemBuilder:(_,i){final d=days[i];return ChoiceChip(label:Text(_day(d)),selected:d==selected,onSelected:(_)=>onChanged(d));}));String _day(int d){const names=['الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'];return d>=0&&d<names.length?names[d]:'اليوم';}}
class _ClassCard extends StatelessWidget{const _ClassCard({required this.item});final ScheduleItem item;@override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(15),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surface,borderRadius:BorderRadius.circular(20),border:Border.all(color:Theme.of(context).colorScheme.outline.withValues(alpha:.52))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:5,height:70,decoration:BoxDecoration(color:AppColors.primary,borderRadius:BorderRadius.circular(5))),const SizedBox(width:13),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(item.subjectName.isEmpty?'—':item.subjectName,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16)),if(item.subjectCode?.isNotEmpty==true)Text(item.subjectCode!,style:Theme.of(context).textTheme.labelSmall),const SizedBox(height:9),Wrap(spacing:12,runSpacing:6,children:[_Meta(Icons.schedule_rounded,'${item.startTime} – ${item.endTime}'),if(item.room?.isNotEmpty==true)_Meta(Icons.location_on_outlined,item.room!),if(item.lecturer?.isNotEmpty==true)_Meta(Icons.person_outline_rounded,item.lecturer!)])]))]));}
class _Meta extends StatelessWidget{const _Meta(this.icon,this.text);final IconData icon;final String text;@override Widget build(BuildContext context)=>Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:15,color:AppColors.blue),const SizedBox(width:5),Text(text,style:Theme.of(context).textTheme.bodySmall)]);}
class _Message extends StatelessWidget{const _Message({required this.text});final String text;@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(35),child:Center(child:Column(children:[const Icon(Icons.event_busy_rounded,size:52,color:AppColors.blue),const SizedBox(height:12),Text(text,textAlign:TextAlign.center)])));}
