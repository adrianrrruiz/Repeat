import type { Metadata, Viewport } from 'next';
import './globals.css';
export const metadata:Metadata={title:'Repeat · Tus hábitos',description:'Tu rutina, a tu ritmo. Un espacio personal para construir hábitos sin límites.',manifest:'/manifest.webmanifest',icons:{icon:'/favicon.svg',apple:'/icon-192.png'},appleWebApp:{capable:true,statusBarStyle:'default',title:'Repeat'}};
export const viewport:Viewport={width:'device-width',initialScale:1,viewportFit:'cover',themeColor:'#ffffff'};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="es"><body>{children}</body></html>;}
