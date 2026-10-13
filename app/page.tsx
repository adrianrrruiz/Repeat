import { requireChatGPTUser } from './chatgpt-auth';
import Repeat from '@/components/repeat';
export const dynamic='force-dynamic';
export default async function Home(){const user=await requireChatGPTUser('/');return <Repeat displayName={user.fullName??'Mi espacio'} />;}
