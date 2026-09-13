import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

enum EinoMood { idle, thinking, talking, happy, error }

class EinoFace extends StatefulWidget {
  const EinoFace({super.key,this.size=86,this.talking=false,this.mood=EinoMood.idle,this.showGlow=true});
  final double size; final bool talking; final EinoMood mood; final bool showGlow;
  @override State<EinoFace> createState()=>_EinoFaceState();
}
class _EinoFaceState extends State<EinoFace> with SingleTickerProviderStateMixin{
  late final AnimationController _c=AnimationController(vsync:this,duration:const Duration(seconds:3))..repeat(reverse:true);
  @override void dispose(){_c.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:_c,builder:(context,child)=>Transform.translate(offset:Offset(0,-widget.size*.018*_c.value),child:Transform.rotate(angle:(widget.talking?0.015:0.006)*(_c.value-.5),child:child)),child:Stack(alignment:Alignment.bottomCenter,children:[
    if(widget.showGlow)Container(width:widget.size*.95,height:widget.size*.95,decoration:BoxDecoration(shape:BoxShape.circle,boxShadow:[BoxShadow(color:AppColors.primary.withValues(alpha:.24),blurRadius:widget.size*.22,spreadRadius:widget.size*.03)])),
    Container(width:widget.size,height:widget.size*1.18,decoration:BoxDecoration(borderRadius:BorderRadius.circular(widget.size*.24),gradient:const LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[Color(0xFFF9F9F9),Color(0xFFE7EDF2)]),border:Border.all(color:AppColors.primary.withValues(alpha:.5),width:2)),child:ClipRRect(borderRadius:BorderRadius.circular(widget.size*.22),child:Image.asset('assets/images/eino.png',fit:BoxFit.cover))),
  ]));
}
