import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/auth_storage.dart';

class ForgotPasswordScreen extends StatefulWidget {
 const ForgotPasswordScreen({super.key});
 @override State<ForgotPasswordScreen> createState()=>_ForgotPasswordScreenState();
}
class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>{
 final _number=TextEditingController(),_code=TextEditingController(),_password=TextEditingController(),_confirm=TextEditingController();
 ApiClient? _client; AuthStorage? _storage; bool _sending=false,_resetting=false,_sent=false,_hide=true;
 @override void dispose(){_number.dispose();_code.dispose();_password.dispose();_confirm.dispose();_client?.dispose();super.dispose();}
 Future<void> _init() async { _storage??=await AuthStorage.create(); _client??=ApiClient(baseUrl:AppConstants.apiBaseUrl,authStorage:_storage!); }
 Future<void> _request() async {
   if(_number.text.trim().isEmpty)return _msg('أدخل الرقم الجامعي.',true);
   setState(()=>_sending=true); try{await _init();await _client!.postJson('/api/v1/auth/forgot-password',body:{'studentNumber':_number.text.trim()});setState(()=>_sent=true);_msg('تم إرسال رمز من 6 أرقام إلى بريدك الإلكتروني.',false);}
   catch(e){_msg(e is ApiException?e.message:e.toString(),true);} finally{if(mounted)setState(()=>_sending=false);}
 }
 Future<void> _reset() async {
   if(!RegExp(r'^\d{6}$').hasMatch(_code.text.trim()))return _msg('أدخل رمز الاستعادة المكون من 6 أرقام.',true);
   if(_password.text.length<8)return _msg('كلمة المرور الجديدة يجب ألا تقل عن 8 أحرف.',true);
   if(_password.text!=_confirm.text)return _msg('كلمتا المرور غير متطابقتين.',true);
   setState(()=>_resetting=true);try{await _init();await _client!.postJson('/api/v1/auth/reset-password',body:{'studentNumber':_number.text.trim(),'code':_code.text.trim(),'newPassword':_password.text,'confirmPassword':_confirm.text});_msg('تم تغيير كلمة المرور. يمكنك تسجيل الدخول الآن.',false);if(mounted)Future.delayed(const Duration(milliseconds:900),()=>context.go('/login'));}catch(e){_msg(e is ApiException?e.message:e.toString(),true);}finally{if(mounted)setState(()=>_resetting=false);}
 }
 void _msg(String m,bool err){if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(m),backgroundColor:err?Theme.of(context).colorScheme.error:null));}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(AppLocalizations.of(context).t('forgotPassword'))),body:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(22),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:460),child:Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
 Text(AppLocalizations.of(context).t('forgotPasswordHelp'),textAlign:TextAlign.center),
 const SizedBox(height:18),
 TextField(controller:_number,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:AppLocalizations.of(context).t('academicId'),prefixIcon:const Icon(Icons.badge_outlined),border:const OutlineInputBorder())),
 if(_sent)...[
  const SizedBox(height:12),TextField(controller:_code,keyboardType:TextInputType.number,maxLength:6,decoration:InputDecoration(labelText:AppLocalizations.of(context).t('recoveryCode'),prefixIcon:const Icon(Icons.pin_outlined),border:const OutlineInputBorder())),
  TextField(controller:_password,obscureText:_hide,decoration:InputDecoration(labelText:AppLocalizations.of(context).t('newPassword'),prefixIcon:const Icon(Icons.lock_reset_outlined),border:const OutlineInputBorder())),
  const SizedBox(height:10),TextField(controller:_confirm,obscureText:_hide,decoration:InputDecoration(labelText:AppLocalizations.of(context).t('confirmPassword'),prefixIcon:const Icon(Icons.lock_reset_outlined),border:const OutlineInputBorder())),
  const SizedBox(height:14),FilledButton(onPressed:_resetting?null:_reset,child:Text(_resetting?'جارٍ التغيير...':AppLocalizations.of(context).t('resetPassword'))),
 ] else ...[
  const SizedBox(height:14),FilledButton(onPressed:_sending?null:_request,child:Text(_sending?'جارٍ الإرسال...':AppLocalizations.of(context).t('sendRecoveryCode'))),
 ],
 ]))))));
}
