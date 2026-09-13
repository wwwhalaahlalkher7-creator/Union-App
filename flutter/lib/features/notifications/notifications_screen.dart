import 'package:flutter/material.dart';
import '../../core/network/authenticated_client.dart';
import '../../core/network/api_client.dart';
import '../../data/models/notification_item.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../core/theme/design_tokens.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState()=>_NotificationsScreenState();
}
class _NotificationsScreenState extends State<NotificationsScreen> {
  ApiClient? _client; NotificationsRepository? _repo; Future<List<NotificationItem>>? _future;
  @override void initState(){super.initState();_init();}
  Future<void> _init() async {try{_client=await AuthenticatedClient.create();_repo=NotificationsRepository(_client!);if(mounted)setState(()=>_future=_repo!.list());}catch(e){if(mounted)setState(()=>_future=Future.error(e));}}
  @override void dispose(){_client?.dispose();super.dispose();}
  Future<void> _reload() async {final r=_repo;if(r==null)return;final f=r.list();setState(()=>_future=f);await f;}
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:Theme.of(context).colorScheme.surfaceContainerLowest,body:CustomScrollView(slivers:[
    SliverToBoxAdapter(child:_Header(onRefresh:_reload)),
    SliverPadding(padding:const EdgeInsets.fromLTRB(16,14,16,120),sliver:SliverToBoxAdapter(child:FutureBuilder<List<NotificationItem>>(future:_future,builder:(context,s){
      if(s.connectionState==ConnectionState.waiting)return const Padding(padding:EdgeInsets.all(40),child:Center(child:CircularProgressIndicator()));
      if(s.hasError)return const _Message(text:'تعذر تحميل الإشعارات.');
      final items=s.data??const <NotificationItem>[];
      if(items.isEmpty)return const _Message(text:'لا توجد إشعارات جديدة حاليًا.');
      return Column(children:[for(final item in items)_NotificationCard(item:item,onRead:()async{if(item.isRead)return;await _repo?.markRead([item.id]);if(mounted)setState(()=>_future=_repo!.list());})]);
    }))),
  ]));
}
class _Header extends StatelessWidget{const _Header({required this.onRefresh});final VoidCallback onRefresh;@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.fromLTRB(18,10,18,22),decoration:const BoxDecoration(gradient:LinearGradient(begin:AlignmentDirectional.topStart,end:AlignmentDirectional.bottomEnd,colors:[AppColors.navy,Color(0xFF173D5A)]),borderRadius:BorderRadius.vertical(bottom:Radius.circular(28))),child:SafeArea(bottom:false,child:Row(children:[Container(width:48,height:48,decoration:BoxDecoration(color:Colors.white10,borderRadius:BorderRadius.circular(15)),child:const Icon(Icons.notifications_rounded,color:AppColors.primary)),const SizedBox(width:12),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('الإشعارات',style:TextStyle(color:Colors.white,fontSize:21,fontWeight:FontWeight.w900)),SizedBox(height:3),Text('كل ما يهمك، في مكان واحد',style:TextStyle(color:Colors.white70,fontSize:12))])),IconButton(onPressed:onRefresh,icon:const Icon(Icons.refresh_rounded,color:Colors.white))])));}
class _NotificationCard extends StatelessWidget{const _NotificationCard({required this.item,required this.onRead});final NotificationItem item;final VoidCallback onRead;@override Widget build(BuildContext context)=>InkWell(onTap:onRead,borderRadius:BorderRadius.circular(20),child:Container(margin:const EdgeInsets.only(bottom:10),padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:Theme.of(context).colorScheme.surface,borderRadius:BorderRadius.circular(20),border:Border.all(color:item.isRead?Theme.of(context).colorScheme.outline.withValues(alpha:.45):AppColors.primary.withValues(alpha:.55))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:43,height:43,decoration:BoxDecoration(color:item.isRead?AppColors.navy.withValues(alpha:.07):AppColors.primary.withValues(alpha:.12),borderRadius:BorderRadius.circular(13)),child:Icon(item.isRead?Icons.notifications_none_rounded:Icons.notifications_active_rounded,color:item.isRead?AppColors.navy:AppColors.primary)),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(item.title,style:const TextStyle(fontWeight:FontWeight.w900))),if(!item.isRead)Container(width:8,height:8,decoration:const BoxDecoration(shape:BoxShape.circle,color:AppColors.primary))]),const SizedBox(height:6),Text(item.body,maxLines:5,overflow:TextOverflow.ellipsis,style:Theme.of(context).textTheme.bodyMedium)]))])));}
class _Message extends StatelessWidget{const _Message({required this.text});final String text;@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.all(36),child:Center(child:Column(children:[const Icon(Icons.notifications_off_outlined,size:54,color:AppColors.blue),const SizedBox(height:12),Text(text,textAlign:TextAlign.center)])));}
