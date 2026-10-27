import 'package:flutter/material.dart';
import '../../api_service.dart';
import '../imports/scanner_import_dialog.dart';

List<Map<String, dynamic>> _asRows(dynamic v) => v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : <Map<String, dynamic>>[];
String _rowName(Map<String, dynamic> r) => (r['name_ar'] ?? r['name'] ?? r['title'] ?? r['code'] ?? r['id'] ?? 'غير محدد').toString();

// Display-only abbreviation for the department pill in the added-students list.
// Department names are stored unchanged; accept the names/aliases used by existing data.
String _studentListDepartmentName(String value) {
  var normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  normalized = normalized
      .replaceFirst(RegExp(r'^(الهندسة|هندسة)\s+'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا');
  const electricalElectronicsNames = <String>{
    'كهرباء إلكترونية',
    'كهرباء الكترونية',
    'الكهرباء الإلكترونية',
    'الكهرباء الالكترونية',
    'الكهربائية الإلكترونية',
    'الكهربائية الالكترونية',
  };
  if (electricalElectronicsNames.contains(normalized)) return 'كهرباء';
  return value;
}


class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key, required this.api});
  final ApiService api;
  @override State<StudentsPage> createState() => _StudentsPageState();
}
class _StudentsPageState extends State<StudentsPage> {
  final _search = TextEditingController();
  List<Map<String,dynamic>> _students=[], _departments=[], _semesters=[];
  bool _busy=false; String? _error;
  @override void initState(){super.initState(); _load();}
  @override void dispose(){_search.dispose();super.dispose();}
  Future<void> _load() async {
    setState(() { _busy=true; _error=null; });
    try {
      final q=Uri.encodeQueryComponent(_search.text.trim());
      final r=await Future.wait([widget.api.get('/admin/students?limit=100${q.isEmpty?'':'&q=$q'}'),widget.api.get('/departments'),widget.api.get('/semesters')]);
      if(!mounted)return; setState(() { _students=_asRows(r[0]['data']); _departments=_asRows(r[1]['data']); _semesters=_asRows(r[2]['data']); });
    } catch(e){if(mounted){ setState(()=>_error=e.toString()); }} finally{if(mounted){ setState(()=>_busy=false); }}
  }
  String _lookup(List<Map<String,dynamic>> rows,dynamic id){for(final r in rows){if('${r['id']}'=='$id'){ return _rowName(r); }}return 'غير محدد';}
  void _msg(String s,{bool bad=false}){if(mounted){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s),backgroundColor:bad?Theme.of(context).colorScheme.error:null)); }}
  Future<void> _edit([Map<String,dynamic>? s]) async {
    if(_departments.isEmpty){_msg('قائمة الأقسام غير متاحة من الخادم.',bad:true);return;}
    final data=await showDialog<Map<String,dynamic>>(context:context,builder:(_)=>_StudentForm(student:s,departments:_departments,semesters:_semesters));
    if(data==null||!mounted) { return; }
    try{final id=s?['id']?.toString(); if(id==null||id.isEmpty){await widget.api.post('/admin/students',body:data);}else{await widget.api.patch('/admin/students/$id',body:data);} _msg(id==null?'تمت إضافة الطالب.':'تم حفظ بيانات الطالب.');await _load();}catch(e){_msg('تعذر الحفظ: $e',bad:true);}
  }
  Future<void> _scanImport() async {
    if (_departments.isEmpty || _semesters.isEmpty) { _msg('تعذر تحميل الأقسام والفصول الدراسية من الخادم. حدّث البيانات ثم أعد المحاولة.', bad: true); return; }
    final result = await showDialog<bool>(context: context, barrierDismissible: false, builder: (_) => ScannerImportDialog(api: widget.api, type: 'students', departments: _departments, semesters: _semesters));
    if (result == true && mounted) { await _load(); }
  }
  Future<void> _toggle(Map<String,dynamic> s,bool active)async{try{await widget.api.patch('/admin/students/${s['id']}',body:{'active':active?1:0});_msg(active?'تم تفعيل الحساب.':'تم إيقاف الحساب.');await _load();}catch(e){_msg('تعذر تغيير الحالة: $e',bad:true);}}
  Future<void> _setModerator(Map<String,dynamic> s, bool grant) async {
    try {
      await widget.api.patch('/admin/students/${s['id']}/moderator', body: {'isModerator': grant});
      _msg(grant ? 'تم تعيين الطالب مشرفًا.' : 'تم إلغاء منصب المشرف.');
      await _load();
    } catch (e) { _msg('تعذر تغيير منصب المشرف: $e', bad: true); }
  }
  Future<void> _delete(Map<String,dynamic> s)async{
    final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف الطالب نهائيًا؟'),content:Text('حذف ${s['full_name']??s['student_number']} يزيل سجل الطالب وبعض بياناته المرتبطة مثل التعليقات والتفاعلات. لا يمكن التراجع. يمكنك إيقاف الحساب بدلًا من الحذف.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف نهائيًا'))]));
    if(yes!=true||!mounted)return;try{await widget.api.delete('/admin/students/${s['id']}');_msg('تم حذف الطالب.');await _load();}catch(e){_msg('تعذر الحذف: $e',bad:true);}
  }
  @override Widget build(BuildContext context){final t=Theme.of(context);return ListView(padding:const EdgeInsets.all(20),children:[
    Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('إدارة الطلاب',style:t.textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:5),const Text('بيانات الطلاب والتخصص والمستوى وحالة التسجيل.') ])),IconButton(onPressed:_busy?null:_load,tooltip:'تحديث',icon:const Icon(Icons.refresh))]),
    const SizedBox(height:12),Wrap(spacing:10,runSpacing:10,children:[SizedBox(width:340,child:TextField(controller:_search,textInputAction:TextInputAction.search,onSubmitted:(_)=>_load(),decoration:InputDecoration(labelText:'بحث بالاسم أو الرقم الجامعي أو البريد',prefixIcon:const Icon(Icons.search),suffixIcon:IconButton(onPressed:_load,icon:const Icon(Icons.arrow_forward))))),FilledButton.icon(onPressed:()=>_edit(),icon:const Icon(Icons.person_add_alt_1),label:const Text('إضافة طالب')), OutlinedButton.icon(onPressed:_scanImport,icon:const Icon(Icons.document_scanner_outlined),label:const Text('مسح واستيراد'))]),
    const SizedBox(height:14),if(_busy)const LinearProgressIndicator(),if(_error!=null)Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('تعذر تحميل البيانات: $_error'),TextButton(onPressed:_load,child:const Text('إعادة المحاولة'))]))),if(!_busy&&_error==null&&_students.isEmpty)const Padding(padding:EdgeInsets.all(28),child:Center(child:Text('لا توجد نتائج.'))),
    ..._students.map((s){final active=s['active']==1||s['active']==true;final reg=s['registered']==1||s['registered']==true;return Card(margin:const EdgeInsets.only(bottom:10),child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Row(children:[const CircleAvatar(child: Icon(Icons.school_outlined)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${s['full_name']??'اسم غير متوفر'}',style:t.textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w700)),Text('الرقم الجامعي: ${s['student_number']??'—'}'),if('${s['email']??''}'.isNotEmpty)Text(s['email'].toString())])),PopupMenuButton<String>(onSelected:(v){if(v=='edit'){ _edit(s); }if(v=='toggle'){ _toggle(s,!active); }if(v=='delete'){ _delete(s); }if(v=='moderator'){ _setModerator(s, !(s['is_moderator']==1||s['is_moderator']==true)); }},itemBuilder:(_)=>[const PopupMenuItem(value:'edit',child:Text('تعديل البيانات')),PopupMenuItem(value:'toggle',child:Text(active?'إيقاف الحساب':'تفعيل الحساب')),PopupMenuItem(value:'moderator',child:Text((s['is_moderator']==1||s['is_moderator']==true)?'إلغاء منصب مشرف الطالب':'تعيين مشرف طالب')),const PopupMenuItem(value:'delete',child:Text('حذف نهائي'))])]),const Divider(),Wrap(spacing:7,runSpacing:7,children:[_Pill(_studentListDepartmentName(_lookup(_departments,s['department_id']))),_Pill('${_lookup(_semesters,s['current_semester_id'])}'),_Pill(active?'الحساب نشط':'الحساب موقوف'),_Pill(reg?'مسجل في التطبيق':'غير مسجل'),if(s['is_moderator']==1||s['is_moderator']==true)_Pill('مشرف طالب')])])));}),
  ]);}
}
class _StudentForm extends StatefulWidget{const _StudentForm({this.student,required this.departments,required this.semesters});final Map<String,dynamic>? student;final List<Map<String,dynamic>> departments,semesters;@override State<_StudentForm> createState()=>_StudentFormState();}
class _StudentFormState extends State<_StudentForm>{final _form=GlobalKey<FormState>();late final TextEditingController _number,_name,_email;String? _dept,_semester;late bool _active;
 @override void initState(){super.initState();final s=widget.student;_number=TextEditingController(text:s?['student_number']?.toString()??'');_name=TextEditingController(text:s?['full_name']?.toString()??'');_email=TextEditingController(text:s?['email']?.toString()??'');_dept=s?['department_id']?.toString();_semester=s?['current_semester_id']?.toString();_active=s==null||s['active']==1||s['active']==true;}
 @override void dispose(){_number.dispose();_name.dispose();_email.dispose();super.dispose();}
 List<DropdownMenuItem<String>> _opts(List<Map<String,dynamic>> rows)=>rows.map((r)=>DropdownMenuItem(value:r['id'].toString(),child:Text(_rowName(r),overflow:TextOverflow.ellipsis))).toList();
 void _save(){if(!_form.currentState!.validate()||_dept==null){ return; }final data=<String,dynamic>{'student_number':_number.text.trim(),'full_name':_name.text.trim(),'department_id':_dept};if(widget.student!=null){data['email']=_email.text.trim().isEmpty?null:_email.text.trim();data['current_semester_id']=_semester;data['active']=_active?1:0;}Navigator.pop(context,data);}
 @override
 Widget build(BuildContext context) => AlertDialog(
   title: Text(widget.student == null ? 'إضافة طالب' : 'تعديل بيانات الطالب'),
   content: SizedBox(
     width: 460,
     child: SingleChildScrollView(
       child: Form(
         key: _form,
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             TextFormField(controller: _number, decoration: const InputDecoration(labelText: 'الرقم الجامعي *'), validator: (v) => v == null || !RegExp(r'^[0-9]+(?:-[0-9]+)?$').hasMatch(v.trim()) ? 'صيغة الرقم الجامعي غير صالحة' : null),
             TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم الكامل *'), validator: (v) => v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null),
             if(widget.student!=null) TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'البريد الإلكتروني'), keyboardType: TextInputType.emailAddress, validator: (v) => v != null && v.trim().isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim()) ? 'البريد الإلكتروني غير صالح' : null),
             DropdownButtonFormField<String>(initialValue: _dept, isExpanded: true, decoration: const InputDecoration(labelText: 'القسم *'), items: _opts(widget.departments), onChanged: (v) => setState(() => _dept = v), validator: (v) => v == null ? 'اختر القسم' : null),
             if(widget.student!=null) DropdownButtonFormField<String>(initialValue: _semester, isExpanded: true, decoration: const InputDecoration(labelText: 'الصف الدراسي / المستوى'), items: [const DropdownMenuItem<String>(value: null, child: Text('غير محدد')), ..._opts(widget.semesters)], onChanged: (v) => setState(() => _semester = v)),
             if(widget.student!=null) SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('الحساب نشط'), value: _active, onChanged: (v) => setState(() => _active = v)),
           ],
         ),
       ),
     ),
   ),
   actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: _save, child: const Text('حفظ'))],
 );
}

class StaffPage extends StatefulWidget{const StaffPage({super.key,required this.api,required this.currentRole});final ApiService api;final String currentRole;@override State<StaffPage> createState()=>_StaffPageState();}
class _StaffPageState extends State<StaffPage>{List<Map<String,dynamic>> _staff=[];bool _busy=false;String? _error;static const roles={'super_admin':'مدير النظام','content_manager':'مدير المحتوى','academic_manager':'مدير الشؤون الأكاديمية'};
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{setState(() { _busy=true; _error=null; });try{final r=await widget.api.get('/admin/staff');if(mounted){ setState(()=>_staff=_asRows(r['data'])); }}catch(e){if(mounted){ setState(()=>_error=e.toString()); }}finally{if(mounted){ setState(()=>_busy=false); }}}
 void _msg(String s,{bool bad=false}){if(mounted){ ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s),backgroundColor:bad?Theme.of(context).colorScheme.error:null)); }}
 Future<void> _edit([Map<String,dynamic>? m])async{final data=await showDialog<Map<String,dynamic>>(context:context,builder:(_)=>_StaffForm(member:m));if(data==null||!mounted){ return; }try{final id=m?['id']?.toString();if(id==null||id.isEmpty){await widget.api.post('/admin/staff',body:data);}else{await widget.api.patch('/admin/staff/$id',body:data);}_msg(id==null?'تم إنشاء الحساب الإداري.':'تم تحديث الحساب الإداري.');await _load();}catch(e){_msg('تعذر حفظ الحساب: $e',bad:true);}}
 Future<void> _toggle(Map<String,dynamic> m,bool active)async{try{await widget.api.patch('/admin/staff/${m['id']}',body:{'active':active});_msg(active?'تم تفعيل الحساب.':'تم تعطيل الحساب.');await _load();}catch(e){_msg('تعذر تغيير الحالة: $e',bad:true);}}
 Future<void> _delete(Map<String,dynamic> m)async{final yes=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('حذف الحساب الإداري؟'),content:Text('سيُحذف حساب ${m['display_name']??m['user_id']} وتُبطل جلساته. لا يمكن التراجع عن هذا الإجراء.'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('إلغاء')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('حذف نهائيًا'))]));if(yes!=true||!mounted){ return; }try{await widget.api.delete('/admin/staff/${m['id']}');_msg('تم حذف الحساب.');await _load();}catch(e){_msg('تعذر الحذف: $e',bad:true);}}
 @override Widget build(BuildContext context){final t=Theme.of(context);return ListView(padding:const EdgeInsets.all(20),children:[Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('الموظفون والصلاحيات',style:t.textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.w800)),const SizedBox(height:5),const Text('حسابات الإدارة والأدوار وحالة الوصول.') ])),IconButton(onPressed:_busy?null:_load,icon:const Icon(Icons.refresh))]),Align(alignment:AlignmentDirectional.centerStart,child:FilledButton.icon(onPressed:()=>_edit(),icon:const Icon(Icons.person_add_alt_1),label:const Text('إنشاء حساب إداري'))),const SizedBox(height:12),const Card(child:Padding(padding:EdgeInsets.all(12),child:Text('حسابات الإدارة منفصلة عن منصب مشرف الطالب. منح الإشراف على التعليقات والدردشة يتم من صفحة الطلاب.'))),if(_busy)const LinearProgressIndicator(),if(_error!=null)Text('تعذر التحميل: $_error'),if(!_busy&&_error==null&&_staff.isEmpty)const Text('لا توجد حسابات إدارية.'),..._staff.map((m){final active=m['active']==1||m['active']==true;final role=m['role_id']?.toString()??'';return Card(margin:const EdgeInsets.only(bottom:10),child:ListTile(leading:CircleAvatar(child:Icon(active?Icons.admin_panel_settings_outlined:Icons.lock_outline)),title:Text('${m['display_name']??m['user_id']}'),subtitle:Text('${m['user_id']??''} · ${roles[role]??role}\n${active?'نشط':'معطّل'}${(m['email']??'').toString().isEmpty?'':' · ${m['email']}'}'),isThreeLine:true,trailing:PopupMenuButton<String>(onSelected:(v){if(v=='edit'){ _edit(m); }if(v=='toggle'){ _toggle(m,!active); }if(v=='delete'){ _delete(m); }},itemBuilder:(_)=>[const PopupMenuItem(value:'edit',child:Text('تعديل')),PopupMenuItem(value:'toggle',child:Text(active?'تعطيل':'تفعيل')),const PopupMenuItem(value:'delete',child:Text('حذف نهائي'))])));})]);}
}
class _StaffForm extends StatefulWidget{const _StaffForm({this.member});final Map<String,dynamic>? member;@override State<_StaffForm> createState()=>_StaffFormState();}
class _StaffFormState extends State<_StaffForm>{final _form=GlobalKey<FormState>();late final TextEditingController _user,_name,_email;final _password=TextEditingController();late String _role;late String _initialRole;late bool _active;
 @override void initState(){super.initState();final m=widget.member;_user=TextEditingController(text:m?['user_id']?.toString()??'');_name=TextEditingController(text:m?['display_name']?.toString()??'');_email=TextEditingController(text:m?['email']?.toString()??'');_role=(m?['role_id']?.toString()??'content_manager');if(!{'super_admin','content_manager','academic_manager'}.contains(_role)){ _role='content_manager'; }_initialRole=m?['role_id']?.toString()??'content_manager';_active=m==null||m['active']==1||m['active']==true;}
 @override void dispose(){_user.dispose();_name.dispose();_email.dispose();_password.dispose();super.dispose();}
 void _save(){if(!_form.currentState!.validate()){ return; }final b=<String,dynamic>{'userId':_user.text.trim(),'displayName':_name.text.trim(),'email':_email.text.trim()};if(widget.member!=null){ b['active']=_active; }if(widget.member==null||_role!=_initialRole){ b['roleId']=_role; }if(_password.text.isNotEmpty){ b['password']=_password.text; }Navigator.pop(context,b);}
 @override
 Widget build(BuildContext context) => AlertDialog(
   title: Text(widget.member == null ? 'إنشاء حساب إداري' : 'تعديل الحساب الإداري'),
   content: SizedBox(
     width: 440,
     child: SingleChildScrollView(
       child: Form(
         key: _form,
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             TextFormField(controller: _user, decoration: const InputDecoration(labelText: 'اسم الدخول *'), validator: (v) => v == null || v.trim().isEmpty ? 'اسم الدخول مطلوب' : null),
             TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم الظاهر *'), validator: (v) => v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null),
             TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'البريد الإلكتروني'), keyboardType: TextInputType.emailAddress),
             TextFormField(controller: _password, decoration: InputDecoration(labelText: widget.member == null ? 'كلمة المرور (8 أحرف على الأقل) *' : 'كلمة مرور جديدة (اختياري)'), obscureText: true, validator: (v) => widget.member == null && (v == null || v.length < 8) ? 'كلمة المرور مطلوبة وبحد أدنى 8 أحرف' : v != null && v.isNotEmpty && v.length < 8 ? '8 أحرف على الأقل' : null),
             DropdownButtonFormField<String>(initialValue: _role, isExpanded: true, decoration: const InputDecoration(labelText: 'الدور'), items: const [DropdownMenuItem(value: 'super_admin', child: Text('مدير النظام')), DropdownMenuItem(value: 'content_manager', child: Text('مدير المحتوى')), DropdownMenuItem(value: 'academic_manager', child: Text('مدير الشؤون الأكاديمية'))], onChanged: (v) { if (v != null) { setState(() => _role = v); } }),
             if(widget.member!=null) SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('الحساب نشط'), value: _active, onChanged: (v) => setState(() => _active = v)),
             if (widget.member != null) const Text('اترك كلمة المرور فارغة للإبقاء على الحالية.'),
           ],
         ),
       ),
     ),
   ),
   actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), FilledButton(onPressed: _save, child: const Text('حفظ'))],
 );
}

class _Pill extends StatelessWidget{const _Pill(this.text);final String text;@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surfaceContainerHighest,borderRadius:BorderRadius.circular(18)),child:Text(text,style:Theme.of(context).textTheme.labelMedium));}
