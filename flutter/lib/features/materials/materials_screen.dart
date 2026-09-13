import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../core/network/authenticated_client.dart';
import '../../data/models/material_item.dart';
import '../../data/repositories/materials_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../core/theme/design_tokens.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});
  @override State<MaterialsScreen> createState() => _MaterialsScreenState();
}
class _MaterialsScreenState extends State<MaterialsScreen> {
  ApiClient? _client;
  MaterialsRepository? _repo;
  ProgressRepository? _progress;
  String? _semesterId;
  List<Map<String,dynamic>> _semesters = [];
  List<Map<String,dynamic>> _subjects = [];
  List<MaterialItem> _materials = [];
  bool _loading = true;
  String? _error;
  @override void initState(){super.initState();_init();}
  @override void dispose(){_client?.dispose();super.dispose();}
  Future<void> _init() async { try { _client=await AuthenticatedClient.create(); _repo=MaterialsRepository(_client!); _progress=ProgressRepository(_client!); await _load(); } catch(e){ if(mounted)setState(()=>_error=e.toString()); } }
  Future<void> _load({String? semesterId}) async {
    setState(()=>_loading=true);
    try {
      final r=_repo; if(r==null)return;
      final semesters=await r.semesters();
      final selected=semesterId??_semesterId??_current(semesters);
      final subjects=selected==null?<Map<String,dynamic>>[]:await r.subjects(semesterId:selected);
      final materials=selected==null?<MaterialItem>[]:await r.list(semesterId:selected);
      if(mounted)setState((){_semesters=semesters;_semesterId=selected;_subjects=subjects;_materials=materials;_loading=false;_error=null;});
    } catch(e){if(mounted)setState(()=>_loading=false);if(mounted)setState(()=>_error=e.toString());}
  }
  String? _current(List<Map<String,dynamic>> list){for(final s in list){if(s['is_current']==true||s['is_current']==1)return s['id']?.toString();}return list.isEmpty?null:list.first['id']?.toString();}
  @override Widget build(BuildContext context){
    final groups=<String,List<MaterialItem>>{};
    for(final m in _materials){groups.putIfAbsent(m.subjectId??m.subject??'other',()=>[]).add(m);}
    return Scaffold(backgroundColor:Theme.of(context).colorScheme.surfaceContainerLowest,body:CustomScrollView(slivers:[
      SliverToBoxAdapter(child:_PageHeader(title:'المواد الدراسية',subtitle:'مواد تخصصك مرتبة حسب الفصل',icon:Icons.menu_book_rounded,onRefresh:_load)),
      SliverPadding(padding:const EdgeInsets.fromLTRB(16,14,16,120),sliver:SliverList(delegate:SliverChildListDelegate([
        if(_error!=null&&_semesters.isEmpty)_Message(text:'تعذر تحميل المواد.\n$_error',retry:_load),
        if(_semesters.isNotEmpty)DropdownButtonFormField<String>(value:_semesterId,decoration:const InputDecoration(labelText:'الفصل الدراسي',prefixIcon:Icon(Icons.calendar_month_rounded)),items:_semesters.map((s)=>DropdownMenuItem(value:s['id']?.toString(),child:Text((s['name_ar']??s['name']??'الفصل').toString()))).toList(),onChanged:(v){if(v!=null)_load(semesterId:v);}),
        const SizedBox(height:18),
        if(_loading)const LinearProgressIndicator(minHeight:3),
        const SizedBox(height:10),
        if(!_loading&&_subjects.isEmpty)const _Empty(icon:Icons.menu_book_outlined,text:'لا توجد مقررات متاحة لهذا الفصل والتخصص حاليًا.'),
        ..._subjects.map((subject){final id=subject['id']?.toString()??'';return _Subject(subject:subject,items:groups[id]??[],progress:_progress);}),
        if(!_loading&&_subjects.isNotEmpty&&_materials.isEmpty)const _Empty(icon:Icons.folder_open_rounded,text:'المقررات موجودة، لكن لا توجد ملفات منشورة بعد.'),
      ]))),
    ]));
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title,required this.subtitle,required this.icon,required this.onRefresh});
  final String title,subtitle; final IconData icon; final VoidCallback onRefresh;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.fromLTRB(18,10,18,22),decoration:const BoxDecoration(gradient:LinearGradient(begin:AlignmentDirectional.topStart,end:AlignmentDirectional.bottomEnd,colors:[AppColors.navy,Color(0xFF173D5A)]),borderRadius:BorderRadius.vertical(bottom:Radius.circular(28))),child:SafeArea(bottom:false,child:Row(children:[Container(width:48,height:48,decoration:BoxDecoration(color:Colors.white10,borderRadius:BorderRadius.circular(15)),child:Icon(icon,color:AppColors.primary)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(subtitle,style:const TextStyle(color:Colors.white70,fontSize:12))])),IconButton(onPressed:onRefresh,icon:const Icon(Icons.refresh_rounded,color:Colors.white))])));
}
class _Subject extends StatelessWidget {
  const _Subject({required this.subject,required this.items,required this.progress});
  final Map<String,dynamic> subject; final List<MaterialItem> items; final ProgressRepository? progress;
  @override Widget build(BuildContext context){final name=(subject['name_ar']??subject['name']??'مادة').toString();final code=(subject['code']??'').toString();return Container(margin:const EdgeInsets.only(bottom:12),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surface,borderRadius:BorderRadius.circular(21),border:Border.all(color:Theme.of(context).colorScheme.outline.withValues(alpha:.52))),child:Theme(data:Theme.of(context).copyWith(dividerColor:Colors.transparent),child:ExpansionTile(tilePadding:const EdgeInsets.symmetric(horizontal:15,vertical:5),childrenPadding:const EdgeInsets.fromLTRB(12,0,12,10),leading:Container(width:45,height:45,decoration:BoxDecoration(color:AppColors.navy.withValues(alpha:.07),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.menu_book_rounded,color:AppColors.navy)),title:Text(name,style:const TextStyle(fontWeight:FontWeight.w900)),subtitle:Text(code.isEmpty?'${items.length} ملف':'$code • ${items.length} ملف'),children:items.isEmpty?[const Padding(padding:EdgeInsets.all(20),child:Text('لا توجد ملفات لهذا المقرر حاليًا.'))]:items.map((m)=>_MaterialTile(material:m,progress:progress)).toList())));}
}
class _MaterialTile extends StatelessWidget {
  const _MaterialTile({required this.material,required this.progress}); final MaterialItem material; final ProgressRepository? progress;
  @override Widget build(BuildContext context)=>ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:8),leading:Container(width:40,height:40,decoration:BoxDecoration(color:AppColors.primary.withValues(alpha:.11),borderRadius:BorderRadius.circular(12)),child:Icon(material.pinned?Icons.push_pin_rounded:Icons.picture_as_pdf_rounded,color:AppColors.primary,size:19)),title:Text(material.name,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:material.size==null?null:Text(_size(material.size!)),trailing:const Icon(Icons.chevron_left_rounded),onTap:material.url==null?null:()=>_open(context));
  Future<void> _open(BuildContext context) async { try{await progress?.record(materialId:material.id,eventType:'open');}catch(_){ } if(!context.mounted)return; showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,6,20,20),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.picture_as_pdf_rounded,size:44,color:AppColors.primary),const SizedBox(height:10),Text(material.name,textAlign:TextAlign.center,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),if(material.url!=null)SelectableText(material.url!,textAlign:TextAlign.center),const SizedBox(height:16),const Text('حدّث تقدمك أثناء الدراسة.',textAlign:TextAlign.center),const SizedBox(height:12),Wrap(spacing:8,children:[for(final v in [25,50,75,100])OutlinedButton(onPressed:progress==null?null:()async{try{await progress!.record(materialId:material.id,eventType:v==100?'complete':'progress',progressPercent:v);if(context.mounted)Navigator.pop(context);}catch(_){ }},child:Text('$v%'))])])))); }
  static String _size(int b)=>b<1024?'$b B':b<1024*1024?'${(b/1024).round()} KB':'${(b/(1024*1024)).toStringAsFixed(1)} MB';
}
class _Empty extends StatelessWidget{const _Empty({required this.icon,required this.text});final IconData icon;final String text;@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(30),child:Column(children:[Icon(icon,size:52,color:AppColors.blue),const SizedBox(height:12),Text(text,textAlign:TextAlign.center)]));}
class _Message extends StatelessWidget{const _Message({required this.text,required this.retry});final String text;final VoidCallback retry;@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(22),child:Column(children:[const Icon(Icons.cloud_off_rounded,size:55,color:AppColors.blue),const SizedBox(height:12),Text(text,textAlign:TextAlign.center),const SizedBox(height:12),OutlinedButton(onPressed:retry,child:const Text('إعادة المحاولة'))]));}
