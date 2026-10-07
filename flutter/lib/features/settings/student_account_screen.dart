import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/errors/error_message.dart';
import '../../core/storage/auth_storage.dart';
import '../../data/repositories/student_repository.dart';
import '../../core/di/app_dependencies.dart';
import '../../shared/utils/academic_labels.dart';
import '../../shared/widgets/action_feedback.dart';

class StudentAccountScreen extends StatefulWidget {
  const StudentAccountScreen({super.key});
  @override State<StudentAccountScreen> createState() => _StudentAccountScreenState();
}

class _StudentAccountScreenState extends State<StudentAccountScreen> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  late final StudentRepository _repo = AppDependencies.instance.student;
  AuthStorage? _storage;
  List<Map<String,dynamic>> _semesters = const [];
  String? _semesterId;
  Map<String,dynamic>? _profile;
  bool _loading = true, _savingSemester = false, _changingPassword = false;
  bool _hideCurrent = true, _hideNew = true, _hideConfirm = true;

  @override void initState(){super.initState(); _load();}
  @override void dispose(){_currentPassword.dispose();_newPassword.dispose();_confirmPassword.dispose();super.dispose();}

  Future<void> _load() async {
    try {
      _storage=AppDependencies.instance.authStorage;
      final profile=await _repo.profile();
      final semesters=await _repo.semesters();
      if(!mounted)return;
      setState((){_profile={'name':profile.name,'number':profile.number,'department':profile.departmentName??'—','email':profile.email};_semesterId=profile.semesterId;_semesters=semesters;_loading=false;});
    } catch(e){if(mounted){setState(()=>_loading=false);_message(ErrorMessage.from(context, e, fallbackKey: 'connectionFailed'),true);}}
  }

  Future<void> _saveSemester() async {
    if(_semesterId==null||_savingSemester)return;
    final l10n = AppLocalizations.of(context);
    final languageCode=Localizations.localeOf(context).languageCode;
    setState(()=>_savingSemester=true);
    try {
      await AppDependencies.instance.apiClient.postJson('/api/v1/student/semester',body:{'semesterId':_semesterId});
      final selected=_semesters.firstWhere((x)=>x['id']?.toString()==_semesterId,orElse:()=>{});
      await _storage?.updateCachedSemester(semesterId:_semesterId!,semesterName:AcademicLabels.semester(selected,languageCode));
      if (mounted) _message(l10n.t('semesterSaved'), false);
    } catch(e){_message(ErrorMessage.from(context, e, fallbackKey: 'connectionFailed'), true);}
    finally{if(mounted)setState(()=>_savingSemester=false);}
  }

  Future<void> _changePassword() async {
    if(_changingPassword)return;
    if(_newPassword.text.length<8){_message(AppLocalizations.of(context).t('passwordTooShortLocal'),true);return;}
    if(_newPassword.text!=_confirmPassword.text){_message(AppLocalizations.of(context).t('passwordMismatchLocal'),true);return;}
    setState(()=>_changingPassword=true);
    try {
      await AppDependencies.instance.apiClient.postJson('/api/v1/auth/change-password',body:{
        'currentPassword':_currentPassword.text,'newPassword':_newPassword.text,'confirmPassword':_confirmPassword.text,
      });
      _currentPassword.clear();_newPassword.clear();_confirmPassword.clear();
      await _storage?.clear();
      if(mounted) context.go('/login');
    } catch(e){_message(ErrorMessage.from(context, e, fallbackKey: 'connectionFailed'), true);}
    finally{if(mounted)setState(()=>_changingPassword=false);}
  }

  void _message(String text, bool error){
    if(!mounted)return;
    if (!error) {
      ActionFeedback.show(context, type: ActionFeedbackType.success);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content:Text(text),backgroundColor:Theme.of(context).colorScheme.error),
    );
  }
  InputDecoration _dec(String label,IconData icon)=>InputDecoration(labelText:label,prefixIcon:Icon(icon),border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)));

  @override Widget build(BuildContext context){
    final l10n=AppLocalizations.of(context);
    if(_loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));
    return Scaffold(
      appBar:AppBar(title:Text(l10n.t('accountSettings'))),
      body:ListView(padding:const EdgeInsets.all(16),children:[
        Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text(l10n.t('studentData'),style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800)),
          const SizedBox(height:12),
          _info('name',_profile?['name']),_info('academicId',_profile?['number']),_info('department',_profile?['department']),_info('email',(_profile?['email'] as String?)?.isNotEmpty==true?_profile!['email']:'—'),
          const SizedBox(height:8),
          DropdownButtonFormField<String>(
            initialValue:_semesters.any((x)=>x['id']?.toString()==_semesterId)?_semesterId:null,
            items:_semesters.map((x)=>DropdownMenuItem(value:x['id']?.toString(),child:Text(AcademicLabels.semester(x,Localizations.localeOf(context).languageCode)))).toList(),
            onChanged:(v)=>setState(()=>_semesterId=v),
            decoration:_dec(l10n.t('semester'),Icons.calendar_month_outlined),
          ),
          const SizedBox(height:10),
          FilledButton.icon(onPressed:_savingSemester?null:_saveSemester,icon:const Icon(Icons.save_outlined),label:Text(_savingSemester?l10n.t('savingSemester'):l10n.t('saveSemester'))),
        ]))),
        const SizedBox(height:12),
        Card(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Row(
            children:[
              Expanded(child:Text(l10n.t('changePassword'),style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.w800))),
              Icon(Icons.shield_outlined,color:Theme.of(context).colorScheme.primary),
            ],
          ),
          const SizedBox(height:6),
          Text(l10n.t('changePasswordHelp'),style:TextStyle(color:Theme.of(context).colorScheme.onSurfaceVariant,height:1.45)),
          const SizedBox(height:14),
          TextField(controller:_currentPassword,obscureText:_hideCurrent,decoration:_dec(l10n.t('currentPassword'),Icons.lock_outline).copyWith(suffixIcon:IconButton(icon:Icon(_hideCurrent?Icons.visibility:Icons.visibility_off),onPressed:()=>setState(()=>_hideCurrent=!_hideCurrent)))),
          const SizedBox(height:10),
          TextField(controller:_newPassword,obscureText:_hideNew,decoration:_dec(l10n.t('newPassword'),Icons.lock_reset_outlined).copyWith(suffixIcon:IconButton(icon:Icon(_hideNew?Icons.visibility:Icons.visibility_off),onPressed:()=>setState(()=>_hideNew=!_hideNew)))),
          const SizedBox(height:10),
          TextField(controller:_confirmPassword,obscureText:_hideConfirm,decoration:_dec(l10n.t('confirmPassword'),Icons.lock_reset_outlined).copyWith(suffixIcon:IconButton(icon:Icon(_hideConfirm?Icons.visibility:Icons.visibility_off),onPressed:()=>setState(()=>_hideConfirm=!_hideConfirm)))),
          const SizedBox(height:14),
          FilledButton.icon(onPressed:_changingPassword?null:_changePassword,icon:const Icon(Icons.password_outlined),label:Text(_changingPassword?l10n.t('changingPassword'):l10n.t('changePassword'))),
          const SizedBox(height:4),
          TextButton.icon(
            onPressed:_changingPassword?null:(){
              final number=(_profile?['number'] as String?)?.trim() ?? '';
              final query=number.isEmpty?'':'?studentNumber=${Uri.encodeComponent(number)}';
              context.push('/forgot-password$query');
            },
            icon:const Icon(Icons.lock_reset_outlined),
            label:Text(l10n.t('forgotPasswordFromSettings')),
          ),
        ]))),
      ]),
    );
  }

  Widget _info(String key,dynamic value)=>Padding(padding:const EdgeInsets.only(bottom:8),child:Row(children:[Expanded(child:Text(AppLocalizations.of(context).t(key),style:const TextStyle(fontWeight:FontWeight.w700))),Expanded(flex:2,child:Text('${value??'—'}'))]));
}
